const ast = @import("ast.zig");
const std = @import("std");
const sub_parser = @import("sub_parser.zig");
const SubParser = sub_parser.SubParser;
const SubNodeList = sub_parser.SubNodeList;
const SubNode = sub_parser.SubNode;

const Node = struct {};

const NodeIndex = usize; // NodeのIndexを表す型
const SubNodeIndex = usize; // SubNodeのIndexを表す型
const NodeTag = enum(u4) {
    S, // 主語
    O, // 目的語
    C, // 補語
    V, // 動詞
    P, // 前置詞句
    A, // 副詞句
    M, // 形容詞句
    SV, // SV型の文
    SVO, // SVO型の文
    SVC, // SVC型の文
    SVOC, // SVOC型の文
    SVOO, // SVOO型の文
    Let, // Let構文
    Suppose, // Suppose構文
    CopulaSVC, // 主語がis, are, beのSVC型の文
    CopulaVSC, // 主語がis, are, beのVSC型の文
};

const NodePattern = union(enum) {
    Identifier: struct {
        subNodeIndex: SubNodeIndex, // 主語のSubNodeのIndex
    },
};

const NextLinkNode = struct {
    tag: NodeTag, // ノードの種類
    pattern: NodePattern, // ノードのパターン
    thisNodeIndex: NodeIndex, // このノードのIndex
    linkHashIndex: usize, // LinkHashMapでのIndex
    start_token_index: usize, // 開始トークンのIndex
    end_token_index: usize, // 終了トークンのIndex
};

const NextLink = struct {
    allocator: std.mem.Allocator,
    tokens: ast.TokenAndStateList,
    subNodeList: SubNodeList,
    nodes: std.ArrayList(Node),
    errors: std.ArrayList(ast.Error),
    linkHash: LinkHashMap,

    saveSubNodeList: ?SubNodeList = null,
    saveNodes: ?std.ArrayList(Node) = null,
    saveErrors: ?std.ArrayList(ast.Error) = null,
    saveLinkHash: ?LinkHashMap = null,

    const LinkHashMap = std.AutoHashMap(usize, usize); // tokenのIndex => NodeのIndex

    pub fn init(allocator: std.mem.Allocator, tokens: ast.TokenAndStateList) !NextLink {
        return NextLink{
            .allocator = allocator,
            .tokens = tokens,
            .subNodeList = SubNodeList{},
            .nodes = std.ArrayList(Node).init(allocator),
            .errors = std.ArrayList(ast.Error).init(allocator),
            .linkHash = LinkHashMap.init(allocator),
        };
    }

    pub fn deinit(self: *NextLink) void {
        self.subNodeList.deinit();
        self.nodes.deinit();
        self.errors.deinit();
        self.linkHash.deinit();
        if (self.saveSubNodeList) |subNodeList| {
            subNodeList.deinit();
        }
        if (self.saveNodes) |nodes| {
            nodes.deinit();
        }
        if (self.saveErrors) |errors| {
            errors.deinit();
        }
        if (self.saveLinkHash) |linkHash| {
            linkHash.deinit();
        }
    }

    fn tryModeInit(self: *NextLink) !void {
        self.saveSubNodeList = self.subNodeList.clone(self.allocator) catch |err| {
            self.errors.append(ast.Error{ .message = "Failed to clone SubNodeList", .index = 0 });
            return err;
        };
        self.saveNodes = self.nodes.clone(self.allocator) catch |err| {
            self.errors.append(ast.Error{ .message = "Failed to clone Nodes", .index = 0 });
            return err;
        };
        self.saveErrors = self.errors.clone(self.allocator) catch |err| {
            self.errors.append(ast.Error{ .message = "Failed to clone Errors", .index = 0 });
            return err;
        };
        self.saveLinkHash = self.linkHash.clone(self.allocator) catch |err| {
            self.errors.append(ast.Error{ .message = "Failed to clone LinkHashMap", .index = 0 });
            return err;
        };
    }

    fn tryModeCommit(self: *NextLink) !void {
        if (self.saveErrors) |errors| {
            errors.clearAndFree();
        }
        self.saveErrors = null;
        if (self.saveSubNodeList) |subNodeList| {
            subNodeList.clearAndFree();
        }
        self.saveSubNodeList = null;
        if (self.saveNodes) |nodes| {
            nodes.clearAndFree();
        }
        self.saveNodes = null;
        if (self.saveLinkHash) |linkHash| {
            linkHash.clearAndFree();
        }
        self.saveLinkHash = null;
    }

    fn tryModeRollback(self: *NextLink) !void {
        if (self.saveErrors) |errors| {
            self.errors = errors;
        }
        if (self.saveSubNodeList) |subNodeList| {
            self.subNodeList = subNodeList;
        }
        if (self.saveNodes) |nodes| {
            self.nodes = nodes;
        }
        if (self.saveLinkHash) |linkHash| {
            self.linkHash = linkHash;
        }
        self.saveErrors = null;
        self.saveSubNodeList = null;
        self.saveNodes = null;
        self.saveLinkHash = null;
    }

    pub fn parse(self: *NextLink) !void {
        // Step 1: to句などの解釈順で差の出ない構文
        try self.parsePrepositions();

        // Step 2: preCheckされた構文
        try self.parsePreCheckedStructures();

        // Step 3: 主語が明確な文(I, You, We, It)
        try self.parseExplicitSubjectSentences();

        // Step 4: 動詞から始まる文
        try self.parseVerbInitiatedSentences();

        // Step 5: 未解析tokenのチェック
        try self.checkUnparsedTokens();
    }

    // 主語のパース
    pub fn parseNormalS(self: *NextLink, startIndex: usize) !void {
        var index = startIndex;
        while (index < self.tokens.len) : (index += 1) {
            const token = self.tokens.items(.token)[index];
            if (token.kind == ast.TokenKind.EOF) break;

            // ここでSubNodeを解析していく
            const subNode = try self.subParser.parseSubNode(index);
            try self.subNodeList.append(subNode);

            // Nodeを生成して追加
            const node = Node{};
            try self.nodes.append(node);

            // LinkHashMapに登録
            try self.subParser.linkHashMap.put(index, self.nodes.len - 1);
        }
    }

    // 主語(動詞がis,are,be)のパース
    pub fn parseCopulaS(self: *NextLink, startIndex: usize) !void {
        var index = startIndex;
        while (index < self.tokens.len) : (index += 1) {
            const token = self.tokens.items(.token)[index];
            if (token.kind == ast.TokenKind.EOF) break;

            // ここでSubNodeを解析していく
            const subNode = try self.subParser.parseCopulaSubNode(index);
            try self.subNodeList.append(subNode);

            // Nodeを生成して追加
            const node = Node{};
            try self.nodes.append(node);

            // LinkHashMapに登録
            try self.subParser.linkHashMap.put(index, self.nodes.len - 1);
        }
    }

    // 目的語のパース
    pub fn parseO(self: *NextLink, startIndex: usize) !void {
        var index = startIndex;
        while (index < self.tokens.len) : (index += 1) {
            const token = self.tokens.items(.token)[index];
            if (token.kind == ast.TokenKind.EOF) break;

            // ここでSubNodeを解析していく
            const subNode = try self.subParser.parseObjectSubNode(index);
            try self.subNodeList.append(subNode);

            // Nodeを生成して追加
            const node = Node{};
            try self.nodes.append(node);

            // LinkHashMapに登録
            try self.subParser.linkHashMap.put(index, self.nodes.len - 1);
        }
    }
};
