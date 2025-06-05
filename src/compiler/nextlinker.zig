const ast = @import("ast.zig");
const sub_parser = @import("sub_parser.zig");
const std = @import("std");
const Error = ast.Error;
const SubParser = sub_parser.SubParser;
const TokenAndStateList = ast.TokenAndStateList;
const Fnv1a_32 = std.hash.Fnv1a_32;

const LinkNode = struct {
    tag: NodeTag, // ノードの種類
    pattern: NodePattern,
};

const SubNodeIndex = usize; // SubNodeのIndexを表す型

const HashType = u32;

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
    Math, // 数学的な式
    Array, // 配列だが、どちらかと言うと何かの並びという意味合いが強い
    // Define, // 定義文
    CopulaSVC,
    Block, // Whileの内側や、関数、動詞の定義の内側、条件文の内側など
    Loop, // ループ文
    EIGoText, // 文全体
};

const NodePattern = union(enum) {
    Identifier: struct { // 単体のS,V,O,Cなど
        node: SubNodeIndex, // 主語のSubNodeのIndex
    },
    OptionalIdentifier: struct {
        node: SubNodeIndex, // 主語のSubNodeのIndex
        option: ?SubNodeIndex, // オプションのSubNodeのIndex 主に副詞句や前置詞句など
    },
    MainAndAction: struct { // SVなどで使える
        main: SubNodeIndex, // 主なSubNodeのIndex
        action: SubNodeIndex, // 動詞のSubNodeのIndex
    },
    ActionAndSub: struct { // VO VCなどで使える
        action: SubNodeIndex, // 動詞のSubNodeのIndex
        sub: SubNodeIndex, // サブのSubNodeのIndex
    },
    MainAndActionAndSub: struct { // SVO,SVCなどで使える
        main: SubNodeIndex, // 主なSubNodeのIndex
        action: SubNodeIndex, // 動詞のSubNodeのIndex
        sub: SubNodeIndex, // サブのSubNodeのIndex
    },
    ActionAndTwoSub: struct { // SVOOなどで使える
        action: SubNodeIndex, // 動詞のSubNodeのIndex
        sub1: SubNodeIndex, // サブのSubNodeのIndex1
        sub2: SubNodeIndex, // サブのSubNodeのIndex2
    },
    MainAndActionAndTwoSub: struct { // SVOCなどで使える
        main: SubNodeIndex, // 主なSubNodeのIndex
        action: SubNodeIndex, // 動詞のSubNodeのIndex
        sub1: SubNodeIndex, // サブのSubNodeのIndex1
        sub2: SubNodeIndex, // サブのSubNodeのIndex2
    },
    LeftAndOperatorAndRight: struct { // 二項演算子などで使える
        left: SubNodeIndex, // 左辺のSubNodeのIndex
        operator: SubNodeIndex, // 演算子のSubNodeのIndex
        right: SubNodeIndex, // 右辺のSubNodeのIndex
    },
    // これで前置詞や不定詞、SVOパターン,that節などを表現できる
};

fn createHash(lv: usize, start_index: usize) HashType {
    var bytes: [@sizeOf(usize) * 2]u8 = undefined;
    std.mem.writeInt(usize, bytes[0..@sizeOf(usize)], lv, .little);
    std.mem.writeInt(usize, bytes[@sizeOf(usize) .. @sizeOf(usize) * 2], start_index, .little);

    return Fnv1a_32.hash(bytes[0..]);
}

const ParseNodeContentsWithoutHash = struct {
    node: LinkNode,
    lv: usize,
    start_index: usize, // 開始トークンのIndex
    end_index: usize, // 終了トークンのIndex

    pub fn hash(self: *ParseNodeContentsWithoutHash) HashType {
        return createHash(self.lv, self.start_index);
    }
};

const ParseNodeContents = struct {
    node: LinkNode,
    lv: usize,
    start_index: usize, // 開始トークンのIndex
    end_index: usize, // 終了トークンのIndex
    hash: HashType,

    //新しい構造体を作る時
    pub fn init(contents: ParseNodeContentsWithoutHash) ParseNodeContents {
        return ParseNodeContents{
            .node = contents.node,
            .lv = contents.lv,
            .start_index = contents.start_index,
            .end_index = contents.end_index,
            .hash = contents.hash(),
        };
    }

    pub fn isSame(self: *ParseNodeContents, other: ParseNodeContents) bool {
        return self.hash == other.hash;
    }
};

const ParserNodesList = std.MultiArrayList(ParseNodeContents);

const ParseNodeErrorContents = struct {
    err: Error,
    lv: usize,
};

const ParseNodeErrorList = std.MultiArrayList(ParseNodeErrorContents);

const CacheHashMap = std.AutoHashMap(HashType, ParseNodeContents);

pub const NextLinker = struct {
    allocator: std.mem.Allocator,
    tokens: TokenAndStateList,
    subParser: SubParser,
    linkHash: std.AutoHashMap(usize, SubNodeIndex),

    nodes: std.MultiArrayList(LinkNode),

    peeks: ParserNodesList, // 現在のパース候
    cachePeeks: CacheHashMap, // peeksのキャッシュ

    peeksErrors: ParseNodeErrorList, // 現在のパース候補のエラー

    pub fn init(allocator: std.mem.Allocator, tokens: TokenAndStateList) !NextLinker {
        return NextLinker{
            .allocator = allocator,
            .tokens = tokens,
            .subParser = SubParser.init(allocator, tokens),
            .linkHash = std.AutoHashMap(usize, SubNodeIndex).init(allocator),
            .nodes = std.MultiArrayList(LinkNode).init(allocator),
            .peeks = ParserNodesList.init(allocator),
            .cachePeeks = CacheHashMap.init(allocator),
            .peeksErrors = ParseNodeErrorList.init(allocator),
        };
    }

    /// levelParserの仕組みをどうするか
    /// レベルはmatchingの深さを表す
    /// 例えばto ~ でマッチする構文が二つある際には、lv0の時ははじめにマッチする物
    /// lv1の時は二つ目のマッチする物を選ぶ 内部にmatch変数を作り、パーサーにあたるたびにmatchをインクリメント
    /// lv0の時はmatchが0のもの、lv1の時はmatchが1のものを選ぶ
    /// 深さは優先しずにそのTokenのみ
    fn parser(self: *NextLinker, level: u4) !void {
        _ = level;
        _ = self;
    }

    // try関数は呼び出す必要がなく、複雑になるので、commit or refreshで管理をする

    fn commit(self: *NextLinker) !void {
        // peeksの中身をcommitさせる
        // 実際にはnodesに追加をして、peeksをからにする
        try self.clearCache();
        if (self.subParser.peeks.len == 0) return;
        try self.joinNodeAndPeek();
    }

    fn joinNodeAndPeek(self: *NextLinker) !void {
        try self.nodes.ensureTotalCapacity(self.allocator, self.nodes.len + self.peeks.len);

        for (0..self.peeks.len) |i| {
            const peek = self.peeks.get(i);
            self.nodes.appendAssumeCapacity(LinkNode{
                .tag = peek.node.tag,
                .pattern = peek.node.pattern,
            });
        }

        self.peeks.clearRetainingCapacity();
    }

    fn clearCache(self: *NextLinker) !void {
        // cachePeeksを空にする
        // self.cachePeeksの解放
        self.cachePeeks.clearAndFree();
    }

    fn popCache(self: *NextLinker, hash: HashType) ?ParseNodeContents {
        if (self.cachePeeks.get(hash)) |peek| {
            // remove()がvoid型なので、peekは既にcloneされた値
            self.cachePeeks.remove(hash) catch return null;
            return peek;
        }
        return null;
    }

    fn refresh(self: *NextLinker, refreshBaseTokenIndex: usize) !void {
        //peeksの内容をリフレッシュ
        if (self.peeks.len == 0) return;
        // startIndex <= refreshBaseTokenIndexとなるまでpopする
        // popしたものはcachePeeksに追加する
        var i = self.peeks.len;
        while (i > 0) {
            i -= 1;
            const peek: ParseNodeContents = self.peeks.get(i);
            if (peek.start_index <= refreshBaseTokenIndex) break;
            const removedPeek = self.peeks.pop() orelse return error.OutOfBounds;
            const hash = removedPeek.hash;
            if (self.cachePeeks.contains(hash)) continue;
            try self.cachePeeks.put(hash, removedPeek);
        }
    }
};
