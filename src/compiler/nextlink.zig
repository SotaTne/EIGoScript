const ast = @import("ast.zig");
const std = @import("std");
const sub_parser = @import("sub_parser.zig");
const SubParser = sub_parser.SubParser;
const SubNodeList = sub_parser.SubNodeList;
const SubNode = sub_parser.SubNode;
const extraList = std.ArrayList(usize);
const tokenizer = @import("tokenizer.zig");
const LexicalCategory = tokenizer.Token.LexicalCategory;
const Token = tokenizer.Token;

const extraListIndex = usize; // extraListのIndexを表す型

const NodePattern = union(enum) {
    Identifier: struct {
        subNodeIndex: SubNodeIndex, // 主語のSubNodeのIndex
    },
    NodeAndOptional: struct { // 何か、修飾がある際に使える called ~ もここで使うつもり
        subNodeIndex: NodeIndex,
        optionalIndex: ?NodeIndex,
    },
    ConditionalExpr: struct { // ~ and ~ や ~ but ~ , ~ otherwise ~
        left: NodeIndex, // 左辺のSubNodeのIndex
        operatorIndex: SubNodeIndex, // 演算子のSubNodeのIndex
        right: NodeIndex, // 右辺のSubNodeのIndex
        otherwiseSideIndex: ?NodeIndex, // otherwiseのSubNodeのIndex（必要に応じて）
        // 例: ' x is greater than 100, and print "big". ' の場合
        // left = x is greater than 100
        // operatorIndex = and
        // right = print "big"
        // otherwiseSideIndex = null // otherwiseがない場合

        // 例2 : 'x is greater than 100, but print "small", otherwise print "big". ' の場合
        // left = x is greater than 100
        // operatorIndex = but
        // right = print "small"
        // otherwiseSideIndex = print "big"
    },
    MathExpr: struct { // 数学的な式
        left: NodeIndex, // 左辺のSubNodeのIndex
        operatorIndex: SubNodeIndex, // 演算子のSubNodeのIndex
        right: NodeIndex, // 右辺のSubNodeのIndex
    },
    SVOPattern: struct { // 現在進行形や現在分詞、過去分詞などでも共通
        subjectIndex: ?NodeIndex, // 主語のSubNodeのIndex
        verbIndex: NodeIndex, // 動詞のSubNodeのIndex
        objectIndex: NodeIndex, // 目的語のSubNodeのIndex
    },
    SVCPattern: struct {
        subjectIndex: ?NodeIndex, // 主語のSubNodeのIndex
        verbIndex: NodeIndex, // 動詞のSubNodeのIndex
        complementIndex: NodeIndex, // 補語のSubNodeのIndex
    },

    DefinePattern: struct {
        DefineMainNodeIndex: NodeIndex, // 定義のメインノードのIndex
        // I define a function called ~. I define a svoc verb  called ~.
        OptionalTakesIndex: ?NodeIndex,
        // It takes a , b and c,
        // のようなもの
    },

    CopulaSVCPattern: struct {
        subjectIndex: NodeIndex, // 主語のSubNodeのIndex
        verbIndex: NodeIndex, // 動詞のSubNodeのIndex
        complementIndex: NodeIndex, // 補語のSubNodeのIndex
    },

    LetPattern: struct {
        subjectIndex: ?NodeIndex, // 主語のSubNodeのIndex
        letVerbIndex: NodeIndex, // let動詞のSubNodeのIndex
        objectIndex: NodeIndex, // 目的語のSubNodeのIndex
        verbIndex: NodeIndex, // 動詞のSubNodeのIndex
    },
    ToClausePattern: struct {
        toIndex: NodeIndex, // to句のSubNodeのIndex
        verbIndex: NodeIndex, // 動詞というかおそらくSVCPatternのようなもの自身が入る
    },
    LoopPattern: struct {
        loopDefineIndex: NodeIndex, // ループの定義部分 We keep repeating the sequence: の部分
        body: NodeIndex, // ループの本体部分 Rangeが入る
        untilNode: NodeIndex, // ループの終了アクション部分 別にwe stopを使わなかったら終了しない
        // until index is greater than 100, then we stop.
    },
    RangePattern: struct {
        range: NodeRange,
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

const NodeIndex = usize;
const SubNodeIndex = usize;
const NodeTag = enum(u4) {
    S,
    O,
    C,
    V,
    P,
    A,
    M,
    SV,
    SVO,
    SVC,
    SVOC,
    SVOO,
    Let,
    Define, // 定義文
    CopulaSVC,
    Block, // Whileの内側や、関数、動詞の定義の内側、条件文の内側など
    Loop, // ループ文
    Text, // 文全体
};

const ParseStep = enum {
    Prepositions, // Step 1: to句など
    PreChecked, // Step 2: preCheck済み構文
    ExplicitSubject, // Step 3: I, You, We, It文
    VerbInitiated, // Step 4: 動詞開始文
    Validation, // Step 5: 未解析チェック
};

const NodeRange = struct {
    start: NodeIndex, // 範囲の開始ノードIndex
    end: NodeIndex, // 範囲の終了ノードIndex
};

const NextLink = struct {
    allocator: std.mem.Allocator,
    tokens: ast.TokenAndStateList,
    subParser: SubParser, // 追加
    subNodeList: SubNodeList,
    nodes: std.ArrayList(NextLinkNode),
    errors: std.ArrayList(ast.Error),
    linkHash: LinkHashMap,
    // Try機能用の保存領域
    saveSubNodeList: ?SubNodeList = null,
    saveNodes: ?std.ArrayList(NextLinkNode) = null,
    saveErrors: ?std.ArrayList(ast.Error) = null,
    saveLinkHash: ?LinkHashMap = null,
    saveTokenStates: ?std.ArrayList(u4) = null,

    // ノードの範囲指定などのときに使うリスト
    extraNodeIndexList: extraList,

    const LinkHashMap = std.AutoHashMap(usize, NodeIndex);
    const TryConfig = struct {
        maxTryCount: u32 = 3,
        maxTryRange: usize = 20,
    };

    pub fn init(allocator: std.mem.Allocator, tokens: ast.TokenAndStateList) !NextLink {
        return NextLink{
            .allocator = allocator,
            .tokens = tokens,
            .subParser = SubParser.init(allocator),
            .subNodeList = SubNodeList{},
            .nodes = std.ArrayList(NextLinkNode).init(allocator),
            .errors = std.ArrayList(ast.Error).init(allocator),
            .linkHash = LinkHashMap.init(allocator),
            .extraNodeIndexList = extraList.init(allocator),
        };
    }

    pub fn deinit(self: *NextLink) void {
        self.subParser.deinit();
        self.subNodeList.deinit();
        self.nodes.deinit();
        self.errors.deinit();
        self.linkHash.deinit();

        // 保存領域のクリーンアップ
        if (self.saveSubNodeList) |*subNodeList| subNodeList.deinit();
        if (self.saveNodes) |*nodes| nodes.deinit();
        if (self.saveErrors) |*errors| errors.deinit();
        if (self.saveLinkHash) |*linkHash| linkHash.deinit();
        if (self.saveTokenStates) |*states| states.deinit();
    }

    // メインのパース処理
    pub fn parse(self: *NextLink) !void {
        try self.parseStep(.Prepositions);
        try self.parseStep(.PreChecked);
        try self.parseStep(.ExplicitSubject);
        try self.parseStep(.VerbInitiated);
        try self.parseStep(.Validation);
    }

    fn parseStep(self: *NextLink, step: ParseStep) !void {
        switch (step) {
            .Prepositions => try self.parsePrepositions(),
            .PreChecked => try self.parsePreCheckedStructures(),
            .ExplicitSubject => try self.parseExplicitSubjectSentences(),
            .VerbInitiated => try self.parseVerbInitiatedSentences(),
            .Validation => try self.validateUnparsedTokens(),
        }
    }

    // Step 1: 前置詞句など確実な構文
    fn parsePrepositions(self: *NextLink) !void {
        var index: usize = 0;
        while (index < self.tokens.len) {
            if (self.isTokenProcessed(index)) {
                index += 1;
                continue;
            }

            const tokenAndState = self.tokens.get(index);
            if (tokenAndState.kind == ast.TokenKind.EOF) break;

            // to句の検出例
            if (std.mem.eql(u8, "to", self.getTokenText(index))) {
                const endIndex = try self.parseToClause(index);
                if (endIndex > index) {
                    try self.markTokensProcessed(index, endIndex, ast.ThreeFlag.Confirmed);
                    index = endIndex + 1;
                } else {
                    index += 1;
                }
            } else {
                index += 1;
            }
        }
    }

    // Token状態の確認
    fn isTokenProcessed(self: *NextLink, index: usize) bool {
        const tokenAndState = self.tokens.get(index);
        return ast.ThreeFlag.checkFlag(tokenAndState.state, ast.ThreeFlag.Confirmed) or
            ast.ThreeFlag.checkFlag(tokenAndState.state, ast.ThreeFlag.PChecked);
    }

    // Token範囲の状態更新
    fn markTokensProcessed(self: *NextLink, startIndex: usize, endIndex: usize, flag: ast.ThreeFlag) !void {
        var i = startIndex;
        while (i <= endIndex and i < self.tokens.len) : (i += 1) {
            var tokenAndState = self.tokens.get(i);
            tokenAndState.state |= ast.ThreeFlag.getFlag(flag);
            self.tokens.set(i, tokenAndState);
        }
    }

    // 解析済みtokenとの競合チェック
    fn checkTokenConflict(self: *NextLink, startIndex: usize, endIndex: usize) bool {
        var i = startIndex;
        while (i <= endIndex and i < self.tokens.len) : (i += 1) {
            if (self.isTokenProcessed(i)) return true;
        }
        return false;
    }

    // Tokenのテキストを取得（仮の実装）
    fn getTokenText(self: *NextLink, index: usize) []const u8 {
        // 実際の実装ではtokenからテキストを取得
        // これは例なので仮の実装
        _ = self;
        _ = index;
        return "";
    }

    // Try機能の実装
    fn tryModeInit(self: *NextLink) !void {
        self.saveSubNodeList = try self.subNodeList.clone(self.allocator);
        self.saveNodes = try self.nodes.clone();
        self.saveErrors = try self.errors.clone();
        self.saveLinkHash = try self.linkHash.clone();

        // Token状態の保存
        var states = std.ArrayList(u4).init(self.allocator);
        try states.ensureTotalCapacity(self.tokens.len);
        for (0..self.tokens.len) |i| {
            const tokenState = self.tokens.get(i);
            try states.append(tokenState.state);
        }
        self.saveTokenStates = states;
    }

    fn tryModeCommit(self: *NextLink) void {
        self.cleanupSavedState();
    }

    fn tryModeRollback(self: *NextLink) !void {
        if (self.saveSubNodeList) |saved| {
            self.subNodeList.deinit();
            self.subNodeList = saved;
        }
        if (self.saveNodes) |saved| {
            self.nodes.deinit();
            self.nodes = saved;
        }
        if (self.saveErrors) |saved| {
            self.errors.deinit();
            self.errors = saved;
        }
        if (self.saveLinkHash) |saved| {
            self.linkHash.deinit();
            self.linkHash = saved;
        }

        // Token状態の復元
        if (self.saveTokenStates) |savedStates| {
            for (savedStates.items, 0..) |state, i| {
                if (i < self.tokens.len) {
                    var tokenAndState = self.tokens.get(i);
                    tokenAndState.state = state;
                    self.tokens.set(i, tokenAndState);
                }
            }
            savedStates.deinit();
        }

        self.saveSubNodeList = null;
        self.saveNodes = null;
        self.saveErrors = null;
        self.saveLinkHash = null;
        self.saveTokenStates = null;
    }

    fn cleanupSavedState(self: *NextLink) void {
        if (self.saveSubNodeList) |*saved| saved.deinit();
        if (self.saveNodes) |*saved| saved.deinit();
        if (self.saveErrors) |*saved| saved.deinit();
        if (self.saveLinkHash) |*saved| saved.deinit();
        if (self.saveTokenStates) |*saved| saved.deinit();

        self.saveSubNodeList = null;
        self.saveNodes = null;
        self.saveErrors = null;
        self.saveLinkHash = null;
        self.saveTokenStates = null;
    }

    // 構文解析の具体的な実装（例）
    fn parseToClause(self: *NextLink, startIndex: usize) !usize {
        // to句の解析ロジック
        // SubParserを使用した実装
        return try self.subParser.parseToClause(startIndex);
    }

    // ノード作成ヘルパーメソッド
    fn createSVONode(self: *NextLink, subjectIdx: SubNodeIndex, verbIdx: SubNodeIndex, objectIdx: SubNodeIndex, startToken: usize, endToken: usize) !NodeIndex {
        const nodeIndex = self.nodes.items.len;
        const node = NextLinkNode{
            .tag = .SVO,
            .pattern = NodePattern{ .SVOPattern = .{
                .subjectIndex = subjectIdx,
                .verbIndex = verbIdx,
                .objectIndex = objectIdx,
            } },
            .thisNodeIndex = nodeIndex,
            .linkHashIndex = try self.linkHash.count(), // 次のhash index
            .start_token_index = startToken,
            .end_token_index = endToken,
        };
        try self.nodes.append(node);
        try self.linkHash.put(startToken, nodeIndex);
        return nodeIndex;
    }

    fn createSVCNode(self: *NextLink, subjectIdx: SubNodeIndex, verbIdx: SubNodeIndex, complementIdx: SubNodeIndex, startToken: usize, endToken: usize) !NodeIndex {
        const nodeIndex = self.nodes.items.len;
        const node = NextLinkNode{
            .tag = .SVC,
            .pattern = NodePattern{ .SVCPattern = .{
                .subjectIndex = subjectIdx,
                .verbIndex = verbIdx,
                .complementIndex = complementIdx,
            } },
            .thisNodeIndex = nodeIndex,
            .linkHashIndex = try self.linkHash.count(),
            .start_token_index = startToken,
            .end_token_index = endToken,
        };
        try self.nodes.append(node);
        try self.linkHash.put(startToken, nodeIndex);
        return nodeIndex;
    }

    fn createLetNode(self: *NextLink, subjectIdx: SubNodeIndex, letVerbIdx: SubNodeIndex, objectIdx: SubNodeIndex, verbIdx: SubNodeIndex, startToken: usize, endToken: usize) !NodeIndex {
        const nodeIndex = self.nodes.items.len;
        const node = NextLinkNode{
            .tag = .Let,
            .pattern = NodePattern{ .LetPattern = .{
                .subjectIndex = subjectIdx,
                .letVerbIndex = letVerbIdx,
                .objectIndex = objectIdx,
                .verbIndex = verbIdx,
            } },
            .thisNodeIndex = nodeIndex,
            .linkHashIndex = try self.linkHash.count(),
            .start_token_index = startToken,
            .end_token_index = endToken,
        };
        try self.nodes.append(node);
        try self.linkHash.put(startToken, nodeIndex);
        return nodeIndex;
    }

    fn createToClauseNode(self: *NextLink, toIdx: SubNodeIndex, verbIdx: SubNodeIndex, startToken: usize, endToken: usize) !NodeIndex {
        const nodeIndex = self.nodes.items.len;
        const node = NextLinkNode{
            .tag = .P, // 前置詞句として扱う
            .pattern = NodePattern{
                .ToClausePattern = .{
                    .toIndex = toIdx,
                    .verbIndex = verbIdx,
                    .complementsStart = null, // 必要に応じて設定
                },
            },
            .thisNodeIndex = nodeIndex,
            .linkHashIndex = try self.linkHash.count(),
            .start_token_index = startToken,
            .end_token_index = endToken,
        };
        try self.nodes.append(node);
        try self.linkHash.put(startToken, nodeIndex);
        return nodeIndex;
    }

    // ノードパターンによる構文チェック
    fn checkNodeCompatibility(self: *NextLink, nodeIndex: NodeIndex, expectedTag: NodeTag) bool {
        if (nodeIndex >= self.nodes.items.len) return false;
        const node = self.nodes.items[nodeIndex];
        return node.tag == expectedTag;
    }

    // その他のステップの実装
    fn parsePreCheckedStructures(self: *NextLink) !void {
        // Step 2の実装
    }

    fn parseExplicitSubjectSentences(self: *NextLink) !void {
        // Step 3の実装
    }

    fn parseVerbInitiatedSentences(self: *NextLink) !void {
        // Step 4の実装
    }

    fn validateUnparsedTokens(self: *NextLink) !void {
        // Step 5: 未解析tokenのチェック
        var index: usize = 0;
        while (index < self.tokens.len) : (index += 1) {
            const tokenAndState = self.tokens.get(index);
            if (!ast.ThreeFlag.checkFlag(tokenAndState.state, ast.ThreeFlag.Confirmed) and
                !ast.ThreeFlag.checkFlag(tokenAndState.state, ast.ThreeFlag.PChecked))
            {
                if (tokenAndState.kind != ast.TokenKind.EOF) {
                    try self.errors.append(ast.Error{
                        .message = "Unparsed token found",
                        .index = index,
                    });
                }
            }
        }
    }

    pub fn parse(self: *NextLink, index: usize, lv: usize) !void {
        var matchCount: usize = 0;
        // 1. Articleなら名詞句パース
        if (LexicalCategory.checkFlag(self.tokens.items(.category)[index], .Article)) {
            // 例: the beautiful flower
            return try self.parseNounPhrase(index);
        }
        // 2. Pronounなら文型ごとに分岐
        else if (self.eatTokenOrMatchList(index, .{ .I, .We, .You, .It })) |idx| {
            switch (self.tokens.items(.kind)[idx]) {
                .I => {
                    // define文をパース
                    return try self.parseDefineStatement(idx);
                },
                .We => {
                    // while文パース
                    return try self.parseWhileStatement(idx);
                },
                .You => {
                    // 動詞スタート命令パース
                    return try self.parseVerbCommand(idx);
                },
                .It => {
                    // it takes ... の特殊構文
                    if (self.eatTokenKind(idx + 1, .Takes)) |takesIdx| {
                        // it takes x and y ...
                        return try self.parseItTakesPattern(takesIdx);
                    } else {
                        return error.UnsupportedItPattern;
                    }
                },
                else => return error.UnsupportedPronoun,
            }
        }
        // 3. 名詞句スタート
        else if (LexicalCategory.checkFlag(self.tokens.items(.category)[index], .Noun)) {
            return try self.parseNounPhrase(index);
        }
        // 4. 動詞句スタート
        else if (LexicalCategory.checkFlag(self.tokens.items(.category)[index], .Verb)) {
            return try self.parseVerbPhrase(index);
        }
        // 5. toの分岐（to + Verb, to + Noun）
        else if (self.tokens.items(.kind)[index] == .To) {
            const next = index + 1;
            if (LexicalCategory.checkFlag(self.tokens.items(.category)[next], .Verb)) {
                return try self.parseInfinitivePhrase(next);
            } else if (LexicalCategory.checkFlag(self.tokens.items(.category)[next], .Noun)) {
                return try self.parsePrepositionalPhrase(next);
            } else {
                return error.InvalidToUsage;
            }
        }
        // 6. and/or/but (Coordination) の分岐
        else if (LexicalCategory.checkFlag(self.tokens.items(.category)[index], .CoordinatingConjunction)) {
            return try self.parseCoordination(index);
        }
        // // 7. 関係詞that
        // else if (self.tokens.items(.kind)[index] == .That) {
        //     return try self.parseRelativeClause(index);
        // }
        // 8. 否定
        else if (LexicalCategory.checkFlag(self.tokens.items(.category)[index], .Negation)) {
            return try self.parseNegationPhrase(index);
        }
        // 9. more/mostなど
        else if (LexicalCategory.checkFlag(self.tokens.items(.category)[index], .Comparative) or
            LexicalCategory.checkFlag(self.tokens.items(.category)[index], .Superlative))
        {
            return try self.parseComparativePhrase(index);
        } else {
            // サポート外 or 文法エラー
            return error.UnsupportedTopLevelPattern;
        }
    }

    fn eatTokenKind(self: *NextLink, index: usize, pattern: Token.TokenKind) ?usize {
        // パターンにマッチするトークンを探す
        if (index >= self.tokens.len) return null;
        if (self.tokens.items(.kind)[index] == pattern) {
            return index;
        }
        return null;
    }

    pub fn eatTokenOrMatchList(self: *NextLink, index: usize, patterns: []const Token.TokenKind) ?usize {
        // パターンにマッチするトークンを探す
        if (index >= self.tokens.len) return null;
        for (patterns) |pattern| {
            if (self.tokens.items(.kind)[index] == pattern) {
                return index;
            }
        }
        return null;
    }

    pub fn parseWithLv(self: *NextLink, index: usize, lv: u8) !void {
        // ここでlvに応じたパース処理を行う
        // 例えば、lvが1ならば簡単な構文解析、lvが2ならばより複雑な構文解析など

        const current: ast.TokenAndState = self.tokens.get(index);

        var match_count: usize = 0;
        // 動詞の解析
        if (LexicalCategory.checkFlag(current.category, .Verb)) {
            // 動詞から始まるのは動詞だけ
            // これは一番安定している
        }
        // to不定詞の解析
        if (LexicalCategory.checkFlag(current.category, .InfinitiveMarker)) {
            if (match_count == 0) {
                // to不定詞の解析のみ
                // to不定詞以外は別のところ
                // もし、to 不定詞以外の形だったら、match_count += 1;
            }
        } else {
            // その他のトークンの解析
            // ここに他のトークンの解析ロジックを追加
        }
    }
};
