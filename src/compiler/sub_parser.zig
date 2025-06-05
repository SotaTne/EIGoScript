const tokenizer = @import("tokenizer.zig");
const ast = @import("./ast.zig");
const Token = tokenizer.Token;
const TokenAndStateList = ast.TokenAndStateList;
const std = @import("std");
const Error = ast.Error;
const LexicalCategory = Token.LexicalCategory;
const ThreeFlag = ast.ThreeFlag;

/// 文法上の要素（サブノード種別）
pub const SubNodeTag = enum(u5) {
    /// 主語
    Subject,
    /// 動詞句（五文型の主要な型で分化）
    SVVerb, // SV型（run, walk など）
    SVOVerb, // SVO型（have, create など）
    SVCVerb, // SVC型（is, become など）
    SVOCVerb, // SVOC型（make, call など）
    SVOOVerb, // SVOO型（give, send など）

    /// 動名詞句
    SVGerundVerb, // SV型の動名詞句（running, walking など）
    SVOGerundVerb, // SVO型の動名詞句（having, creating など）
    SVCGerundVerb, // SVC型の動名詞句（being, becoming など）
    SVOCGerundVerb, // SVOC型の動名詞句（making, calling など）
    SVOOGerundVerb, // SVOO型の動名詞句（giving, sending など）

    /// 分詞(現在分詞+過去分詞)
    SVParticiple, // SV型の分詞句（running, walking など）
    SVOParticiple, // SVO型の分詞句（having, creating など）
    SVCParticiple, // SVC型の分詞句（being, becoming, calledなど）
    SVOCParticiple, // SVOC型の分詞句（making など）
    SVOOParticiple, // SVOO型の分詞句（giving, sending など）

    /// 句動詞（verb + particle）のparticle部分
    VerbParticle,

    /// 特殊動詞（define, let, suppose など独自構文で分類）
    LetVerb,
    // SupposeVerb,
    // DefineVerb,

    /// 名詞・名詞句
    NounPhrase, // a book, my brother など
    //GerundPhrase, // 動名詞句（動詞ingの名詞用法）
    MathOperator, // 数学演算子（+ - * / など）

    /// 形容詞・副詞・修飾句
    AdjectivePhrase, // 形容詞句
    AdverbPhrase, // 副詞句
    PrepositionalPhrase, // 前置詞句（in the parkなど）
    // PresentParticipleHead, // 現在分詞句のhead（running, walkingなど）
    // PastParticipleHead, // 過去分詞句のhead（broken, seenなど）

    /// 節・句（名詞節・関係節・不定詞節など）
    InfinitiveHead, // 不定詞節（to + 動詞）のto部分
    // RelativeClause, // 関係詞節（who, which, that節など）
    // WhClauseHead, // wh-節（what, who, whereなど）のwh部分

    NegationPhrase, // 否定句（not, noなど）

    /// 汎用的な節や将来の追加用（必要に応じて拡張可能）
    // Clause, // 補文節・従属節（汎用的なものも含める）
    // RelativePronounHead, // 関係代名詞（who, which, thatなど）
    ComparativePhrase, // 比較構文（必要に応じて追加） ~ than ~ や as ~ as ~ など the ~est of ~  the most ~ なども
    // ParticipleClause,   // 分詞構文（今後拡張する場合）

    Conjunction, // 接続詞（and, but, thenなど） これは左にbool右に実行内容の式にする

    SubordinatingConjunction, // 従属接続詞（that, if, when, untilなど）

    /// 不明またはエラー
    Unknown,
};

pub const SubNodeList = std.MultiArrayList(SubNode);

pub const SubNodeIndex = struct {
    index: usize,
    isRoot: bool,
    pub fn updateIndex(self: *SubNodeIndex, base: usize) void {
        self.index += base;
    }
};

/// 結合し index を調整した新しい SubNodeList を返す
pub fn joinSubNodeList(
    baseList: SubNodeList,
    allocator: std.mem.Allocator,
    additionalList: SubNodeList,
) !SubNodeList {
    // 新しい MultiArrayList を初期化
    var result = SubNodeList{};
    errdefer result.deinit(allocator);

    // 事前確保（推奨: appendAssumeCapacity 使用するため）
    try result.ensureTotalCapacity(allocator, baseList.len + additionalList.len);

    // baseList のノードをそのままコピー
    for (0..baseList.len) |i| {
        const node = baseList.get(i);
        result.appendAssumeCapacity(.{
            .startTokenIndex = node.startTokenIndex,
            .tag = node.tag,
            .data = node.data,
            .is_root = node.is_root,
        });
    }

    // index 調整して additionalList を追加
    const baseLen = baseList.len;
    for (0..additionalList.len) |i| {
        var node = additionalList.get(i);
        node.data.updateNodeIndex(baseLen);
        result.appendAssumeCapacity(node);
    }

    return result;
}

pub const SubNodeIndexRange = struct {
    start: SubNodeIndex,
    end: SubNodeIndex,

    pub fn updateIndex(self: *SubNodeIndexRange, base: usize) void {
        self.start.updateIndex(base);
        self.end.updateIndex(base);
    }
};

pub const NodeIndexRangeResult = struct {
    range: SubNodeIndexRange,
    next_token_index: usize, // 次のトークンのインデックス
};

/// S, V, O, C, M等を構成する最小単位の構造体
pub const SubAstStructs = union(enum) {
    /// 単一のトークン（識別子・単語等）
    Identifier: struct {
        tokenIndex: usize,
    },

    /// 句や修飾語（名詞句・形容詞句・副詞句など）共通化
    /// head: 主要要素（例: 名詞/動詞/形容詞など）
    /// pre_modifiers: 前置修飾語（例: very, some, beautiful ...）
    /// post_modifiers: 後置修飾語（例: with 1,2,3 / in the park ...）
    // Phrase: struct {
    //     head: SubNodeIndex,
    //     pre_modifiers: []SubNodeIndex,
    //     post_modifiers: []SubNodeIndex,
    // },

    NounPhrase: struct {
        // 冠詞,修飾,名詞の組み合わせ
        article: ?usize, // 冠詞（a, the, anなど）
        modifiers: ?SubNodeIndexRange, // 修飾語(形容詞句)
        noun: SubNodeIndex, // 名詞（単独の名詞や名詞句）
    },

    /// 形容詞句、動詞句でとりあえず使うつもり 動名詞句でも使う
    MainAndOptionalPhrase: struct {
        main: SubNodeIndex, // 主な要素（例: 名詞句や動詞句）
        optional: ?SubNodeIndex, // オプションの要素（例: 副詞句や前置詞句）
    },

    /// 比較級とかに使う
    OpAndVector: struct {
        op: usize,
        vector: usize, // 比較対象のベクトル（例: "than"の後の部分）
    },

    /// カンマ区切りの列挙（a, b, c など）
    Enumeration: struct {
        etIndex: []SubNodeIndex,
    },

    /// カンマ区切りの列挙（a, b, c など）
    RangeEnumeration: struct {
        start: SubNodeIndex, // 開始要素
        end: SubNodeIndex, // 終了要素
    },

    /// 前置詞とかの句（in the park, on the table など）
    OpAndNode: struct {
        op: usize, // 演算子トークンindex
        node: SubNodeIndex, // 対象のノード（例: 名詞句や動詞句）
    },

    // /// 演算式（a + b + c など再帰可）
    // BinaryOpPhrase: struct {
    //     left: SubNodeIndex,
    //     op: usize, // 演算子トークンindex
    //     right: SubNodeIndex,
    // },

    // /// "list with 1,2,3" などのリスト構文
    // ListPhrase: struct {
    //     list_keyword: usize, // "list"などリストを表すtoken
    //     with_keyword: usize, // "with"トークンindex
    //     elements: []SubNodeIndex,
    // },

    // /// "with a, b, ..." 構文
    // WithPhrase: struct {
    //     with_keyword: usize,
    //     objects: []SubNodeIndex,
    // },

    // /// 節（that節/to節/wh節/関係節など、再帰的に内容を持てる）
    // Clause: struct {
    //     head_token: usize, // that/to/when/while/wh等のtoken
    //     content: SubNodeIndex, // 節の中身
    // },

    /// 不明またはエラー時
    Unknown: struct {
        tokenIndex: usize,
    },

    pub fn updateNodeIndex(self: *SubAstStructs, base: usize) void {
        switch (self.*) {
            //.Identifier => |*id| id.tokenIndex += base,
            // tokenIndexはそのままなので+=baseは不要
            .Phrase => |*p| {
                p.head.updateIndex(base);
                for (p.pre_modifiers) |*m| m.updateIndex(base);
                for (p.post_modifiers) |*m| m.updateIndex(base);
            },

            .NounPhrase => |*n| {
                if (n.modifiers) |*m| m.updateIndex(base);
                n.noun.updateIndex(base);
            },
            // .Enumeration => |*e| {
            //     for (e.etIndex) |*i| i.* += base;
            // },
            // tokenIndexはそのままなので+=baseは不要
            // .BinaryOpPhrase => |*b| {
            //     b.left.
            //     b.right += base;
            //     // opはtoken indexなので+=baseは不要
            // },
            .MainAndOptionalPhrase => |*m| {
                m.main.updateIndex(base);
                if (m.optional) |*o| o.updateIndex(base);
            },
            // 他variantも必要なら追加
            else => {},
        }
    }
};
/// SubNode：NextLinkやSubParserで扱う最小の意味単位
pub const SubNode = struct {
    startTokenIndex: usize,
    tag: SubNodeTag, // 上記タグで種別を明確化
    data: SubAstStructs, // 具体的な構造
    is_root: bool = false, // ルートノードかどうか（NextLinkのルートなど）
};

pub const ParseResult = struct {
    next_token_index: usize, // 解析後の次の位置
    nodes_index: SubNodeIndex, // nodesのどこに追加したか
    tag: SubNodeTag,
};

pub const MainAndOptionalAndNextToken = struct {
    startIndex: usize,
    main: SubNodeIndex, // 主な要素のノード
    optional: ?SubNodeIndex, // オプションの要素のノード
    next_token_index: usize, // 次のトークンのインデックス
    tag: SubNodeTag,
};

pub const SubParserDiff = struct {
    /// 解析結果のノードリスト
    diff_sub_nodes: SubNodeList,
    /// 解析中に発生したエラー
    diff_errors: std.ArrayList(Error),
};

pub const SubParser = struct {
    tokens: *TokenAndStateList,
    tokens_len: usize,
    errors: std.ArrayList(Error),
    allocator: std.mem.Allocator,
    sub_nodes: SubNodeList, // 解析結果のノードリスト
    // diff: SubParserDiff,

    pub fn init(allocator: std.mem.Allocator, tokens: *TokenAndStateList) SubParser {
        return .{
            .tokens = tokens,
            .tokens_len = tokens.len,
            .errors = std.ArrayList(Error).init(allocator),
            .allocator = allocator,
            .sub_nodes = SubNodeList{},
            // .diff = SubParserDiff{
            //     .diff_sub_nodes = SubNodeList{},
            //     .diff_errors = std.ArrayList(Error).init(allocator),
            // },
        };
    }

    pub fn deinit(self: *SubParser) void {
        self.sub_nodes.deinit(self.allocator);
        self.errors.deinit();
    }

    pub fn clear(self: *SubParser) void {
        self.sub_nodes.clearAndFree(self.allocator);
        self.errors.clearAndFree();
    }

    // /// これは関数型言語のatomのような物
    // /// commit, refreshのどちらかを使い、diffの適応や破棄が可能になる
    // pub fn useDiff(self: *SubParser) void {
    //     std.mem.swap(
    //         &self.sub_nodes,
    //         &self.diff.diff_sub_nodes,
    //     );
    //     std.mem.swap(
    //         &self.errors,
    //         &self.diff.diff_errors,
    //     );
    // }

    // pub fn commit(self: *SubParser) void {
    //     std.mem.swap(
    //         &self.sub_nodes,
    //         &self.diff.diff_sub_nodes,
    //     );
    //     joinSubNodeList(
    //         self.allocator,
    //         self.sub_nodes,
    //         self.diff.diff_sub_nodes,
    //     ) catch {
    //         self.errors.append(Error{ .message = "Failed to join SubNodeList", .index = 0 });
    //         return null;
    //     };

    //     self.diff.diff_sub_nodes.clearAndFree(self.allocator);

    //     std.mem.swap(
    //         &self.errors,
    //         &self.diff.diff_errors,
    //     );

    //     self.errors.appendSlice(self.diff.diff_errors.items) catch {
    //         self.errors.append(Error{ .message = "Failed to append diff errors", .index = 0 });
    //         return null;
    //     };

    //     self.diff.diff_errors.clearAndFree();
    // }

    // pub fn refresh(self: *SubParser) void {
    //     // diffを破棄して、現在の状態を保持する
    //     std.mem.swap(
    //         &self.sub_nodes,
    //         &self.diff.diff_sub_nodes,
    //     );
    //     std.mem.swap(
    //         &self.errors,
    //         &self.diff.diff_errors,
    //     );
    //     self.diff.diff_sub_nodes.clearAndFree(self.allocator);
    //     self.diff.diff_errors.clearAndFree();
    // }

    /// 主語にあたるものをパースできる 今回は修飾は含まないが、将来的に必要になる可能性もある
    pub fn parseSubject(self: *SubParser, index: usize) ?ParseResult {
        const subjectIndex = self.eatTokenKindList(index, &.{ .I, .We, .You, .It });
        std.debug.print("parseSubject: index: {any}, subjectIndex: {any}\n", .{ index, subjectIndex });
        if (subjectIndex) |sindex| {
            //self.setCheckedFlag(sindex, sindex + 1);
            const node = SubNode{
                .startTokenIndex = sindex,
                .tag = SubNodeTag.Subject,
                .data = SubAstStructs{
                    .Identifier = .{ .tokenIndex = sindex },
                },
                // .is_root = true, // 主語はルートノードとして扱う
            };
            const nodeIndex = self.addNode(node, true) catch return null;
            return ParseResult{
                .nodes_index = nodeIndex,
                .next_token_index = sindex + 1,
                .tag = SubNodeTag.Subject,
            };
        }
        return null;
    }

    /// 否定語のパースをする
    pub fn parseNegation(self: *SubParser, index: usize) ?ParseResult {
        const negationIndex = self.eatCategory(index, .Negation) orelse return null;
        return self.createSimpleNode(negationIndex, .NegationPhrase) catch return null;
    }

    /// 汎用的な単体トークンノードを生成する（形容詞句・副詞句など）
    fn createSimpleNode(self: *SubParser, index: usize, tag: SubNodeTag) !ParseResult {
        const node = SubNode{
            .startTokenIndex = index,
            .tag = tag,
            .data = SubAstStructs{ .Identifier = .{ .tokenIndex = index } },
        };
        const nodeIndex = try self.addNode(node, false);
        return ParseResult{
            .nodes_index = nodeIndex,
            .next_token_index = index + 1,
            .tag = tag,
        };
    }

    /// 副詞をパースする (very, quite, extremely, slowly など)
    pub fn parsePureAdverb(self: *SubParser, index: usize) ?ParseResult {
        const adv_idx = self.eatCategory(index, .Adverb) orelse return null;
        // Always returns a ParseResult whose nodes_index is a SubNodeIndex (unified type)
        return self.createSimpleNode(adv_idx, .AdverbPhrase) catch return null;
    }

    /// 形容詞をパースする (beautiful, big, red など)
    pub fn parsePureAdjective(self: *SubParser, index: usize) ?ParseResult {
        const adj_idx = self.eatCategory(index, .Adjective) orelse return null;
        // Always returns a ParseResult whose nodes_index is a SubNodeIndex (unified type)
        return self.createSimpleNode(adj_idx, .AdjectivePhrase) catch return null;
    }

    /// 形容詞句をパースする
    pub fn parseAdjective(self: *SubParser, index: usize) ?ParseResult {
        // 形容詞句をパースする
        // 形容詞句は、形容詞とその修飾語（副詞など）を含む
        // very beautiful, quite slowly などの形容詞句をパースする
        // 副詞があるかの確認を行い、形容詞と副詞の組み合わせをパースする
        const adverbResult = self.parsePureAdverb(index);
        const nextIndex = if (adverbResult) |adi| adi.next_token_index else index;
        const adjectiveResult = self.parsePureAdjective(nextIndex) orelse {
            // 形容詞が見つからない場合はnull
            return null;
        };
        // Use buildMainWithOptionalNode utility function
        return self.buildMainWithOptionalNode(
            index,
            SubNodeTag.AdjectivePhrase,
            adjectiveResult.nodes_index,
            if (adverbResult) |adv| adv.nodes_index else null,
            adjectiveResult.next_token_index,
        ) catch return null;
    }

    /// 形容詞句をnodesに追加しずにパースする
    pub fn parseAdjectiveWithoutAddNodes(
        self: *SubParser,
        index: usize,
    ) ?MainAndOptionalAndNextToken {
        // 形容詞句をパースするが、ノードは追加しない
        // 形容詞とその修飾語（副詞など）を含む
        // very beautiful, quite slowly などの形容詞句をパースする
        const adverbResult = self.parsePureAdverb(index);
        const nextIndex = if (adverbResult) |adi| adi.next_token_index else index;
        const adjectiveResult = self.parsePureAdjective(nextIndex) orelse {
            // 形容詞が見つからない場合はnull
            return null;
        };
        return MainAndOptionalAndNextToken{
            .startIndex = index,
            .main = adjectiveResult.nodes_index,
            .optional = if (adverbResult) |adv| adv.nodes_index else null,
            .next_token_index = adjectiveResult.next_token_index,
            .tag = SubNodeTag.AdjectivePhrase,
        };
    }

    /// 副詞句をパースする
    pub fn parseAdverb(self: *SubParser, index: usize) ?ParseResult {
        return self.parsePureAdverb(index);
    }

    /// to不定詞句のヘッドをパースする
    pub fn parseInfinitiveHead(self: *SubParser, index: usize) ?ParseResult {
        // 不定詞句（to + 動詞）をパースする
        // 例: to run, to walk など
        const toIndex = self.eatTokenKind(index, Token.TokenKind.To) orelse return null;
        _ = self.eatCategory(toIndex + 1, .Verb) orelse return null;

        const node = SubNode{
            .startTokenIndex = toIndex,
            .tag = SubNodeTag.InfinitiveHead,
            .data = SubAstStructs{ .Identifier = .{ .tokenIndex = toIndex } },
        };
        const nodeIndex = self.addNode(node, false) catch return null;

        return ParseResult{
            .nodes_index = nodeIndex,
            .next_token_index = toIndex + 1,
            .tag = SubNodeTag.InfinitiveHead,
        };
    }

    /// 動名詞句のヘッドをパースする
    pub fn parseGerund(self: *SubParser, index: usize) ?ParseResult {
        // 動名詞句をパースする
        // 例: running, walking など
        const gerundIndex = self.eatCategory(index, .Gerund) orelse return null;

        const gerundVerbTag = replaceGerundVerbKind(self.tokens.get(index)) orelse return null;

        const gerundNode = self.createSimpleNode(gerundIndex, gerundVerbTag) catch return null;

        const verbParticleIndex = self.eatCategory(gerundIndex + 1, .VerbParticle);
        const verbParticleNode = if (verbParticleIndex) |pi|
            self.createSimpleNode(pi, .VerbParticle) catch return null
        else
            null;

        // デフォルトは単体ノード
        return self.buildMainWithOptionalNode(
            gerundIndex,
            gerundVerbTag,
            gerundNode.nodes_index,
            if (verbParticleNode) |vp| vp.nodes_index else null,
            if (verbParticleIndex) |pi| pi + 1 else gerundIndex + 1,
        ) catch return null;
    }

    /// 動詞をパースする
    /// 動詞は五文型の主要な動詞（SV, SVO, SVC, SVOC, SVOO）を含む
    /// また、特殊な動詞（define, let, supposeなど）も含む
    pub fn parseVerb(self: *SubParser, index: usize) ?ParseResult {
        const verbIndex = self.eatCategory(index, LexicalCategory.Verb) orelse {
            return null;
        };
        const verbKind = replaceVerbKind(self.tokens.get(index)) orelse {
            return null; // 動詞の種別が不明な場合はnull
        };

        const verbNode = SubNode{
            .startTokenIndex = verbIndex,
            .tag = .VerbParticle,
            .data = SubAstStructs{ .Identifier = .{ .tokenIndex = verbIndex } },
        };

        const verbNodeIndex = self.addNode(
            verbNode,
            false,
        ) catch return null;

        // 句動詞のパース
        const verbParticleIndex = self.eatCategory(verbIndex + 1, .VerbParticle);

        const verbParticleNode = if (verbParticleIndex) |pi| SubNode{
            .startTokenIndex = pi,
            .tag = verbKind,
            .data = SubAstStructs{ .Identifier = .{ .tokenIndex = pi } },
        } else null;

        const verbParticleNodeIndex = if (verbParticleNode) |vp|
            self.addNode(vp, false) catch return null
        else
            null;

        // NOTE: buildMainWithOptionalNodeがOptionalノードを構築してくれる
        return self.buildMainWithOptionalNode(
            verbIndex,
            verbKind,
            verbNodeIndex,
            verbParticleNodeIndex,
            if (verbParticleIndex) |pi| pi + 1 else verbIndex + 1,
        ) catch return null;
    }

    pub fn parseOnlyNounPhrase(self: *SubParser, index: usize) ?ParseResult {
        const articleIndex = self.eatCategory(index, .Article);
        const nextIndex = if (articleIndex) |artIdx| artIdx + 1 else index;

        // 形容詞のみを前置修飾として解析
        var currentIndex = nextIndex;
        const adjectiveRange = self.parseAdjectiveList(currentIndex);
        if (adjectiveRange) |range| {
            currentIndex = range.next_token_index;
        }

        const pureNounResult = self.parsePureNoun(currentIndex) orelse return null;

        // 前置詞句は解析しない！NextLinkに委ねる
        // Use unified types for consistency: noun is SubNodeIndex, modifiers is ?SubNodeIndexRange
        const node = SubNode{
            .tag = SubNodeTag.NounPhrase,
            .startTokenIndex = index,
            .data = SubAstStructs{
                .NounPhrase = .{
                    .article = articleIndex,
                    .modifiers = if (adjectiveRange) |rangeResult| rangeResult.range else null, // type: ?SubNodeIndexRange
                    .noun = pureNounResult.nodes_index, // type: SubNodeIndex
                },
            },
        };
        const nodeIndex = self.addNode(node, false) catch return null;
        return ParseResult{
            .nodes_index = nodeIndex,
            .next_token_index = pureNounResult.next_token_index,
            .tag = SubNodeTag.NounPhrase,
        };
    }

    pub fn parsePureNounWithPureList(self: *SubParser, index: usize) ?ParseResult {
        // 純粋な名詞（名詞句ではなく単独の名詞）
        // 例えば "book" や "dog" など
        const nounIndex = self.eatCategory(index, .Noun) orelse {
            return null; // 名詞が見つからない場合はnull
        };

        // リスト形式の場合の処理
        if (nounIndex + 1 < self.tokens_len and self.eatTokenKindList(nounIndex + 1, &.{ .And, .Comma }) != null) {
            return self.parsePureList(index);
        }

        // 数値やStringも名詞として分類されているので、ただそれを返せば良い
        const node = SubNode{
            .startTokenIndex = nounIndex,
            .tag = SubNodeTag.NounPhrase,
            .data = SubAstStructs{ .Identifier = .{ .tokenIndex = nounIndex } },
        };
        const nodeIndex = self.addNode(node, false) catch return null;
        return ParseResult{
            .nodes_index = nodeIndex,
            .next_token_index = nounIndex + 1,
            .tag = SubNodeTag.NounPhrase,
        };
    }

    pub fn parsePureNoun(self: *SubParser, index: usize) ?ParseResult {
        const nounIndex = self.eatCategory(index, .Noun) orelse {
            return null; // 名詞が見つからない場合はnull
        };
        return self.createSimpleNode(nounIndex, .NounPhrase) catch return null;
    }

    pub fn parsePrepositionalPhrase(self: *SubParser, index: usize) ?ParseResult {
        // 前置詞を確認
        const prepIndex = self.eatCategory(index, .Preposition) orelse return null;

        // 前置詞の後の名詞句をパース
        const nounPhraseResult = self.parseOnlyNounPhrase(prepIndex + 1) orelse {
            // 名詞句が見つからない場合はエラー
            return null;
        };

        const node = SubNode{
            .startTokenIndex = index,
            .tag = SubNodeTag.PrepositionalPhrase,
            .data = SubAstStructs{
                .OpAndNode = .{
                    .op = prepIndex,
                    .node = nounPhraseResult.nodes_index,
                },
            },
        };

        const nodeIndex = self.addNode(node, false) catch return null;
        return ParseResult{
            .nodes_index = nodeIndex,
            .next_token_index = nounPhraseResult.next_token_index,
            .tag = SubNodeTag.PrepositionalPhrase,
        };
    }

    pub fn parsePureList(self: *SubParser, index: usize) ?ParseResult {
        // 純粋なリスト（名詞句ではなく単独の名詞）
        // 例えば a,b,c のような形式
        // token , token , tokenのような形式のみ許可
        // 1+2,3,4のようなものは除外する
        // Noun単体が,によって区切られた形式
        // ただし、リストは除外する
        const firstIndex = self.eatCategory(index, .Noun) orelse {
            return null; // 最初の要素が名詞でない場合はnull
        };
        var elements = std.ArrayList(usize).init(self.allocator);
        defer elements.deinit();

        elements.append(firstIndex) catch return null; // 最初の要素を追加
        var nextIndex = firstIndex + 1;

        while (true) {
            if (nextIndex >= self.tokens_len) break; // 範囲外なら終了

            const commaIndex = self.eatTokenKind(nextIndex, Token.TokenKind.Comma);
            const andIndex = self.eatTokenKind(nextIndex, Token.TokenKind.And);

            if (commaIndex) |commaIdx| {
                const nextNounIndex = self.eatCategory(commaIdx + 1, .Noun) orelse {
                    break; // 名詞が見つからない場合は終了
                };
                elements.append(nextNounIndex) catch return null;
                nextIndex = nextNounIndex + 1; // 次の位置を更新
            } else if (andIndex) |andIdx| {
                const nextNounIndex = self.eatCategory(andIdx + 1, .Noun) orelse {
                    break; // 名詞が見つからない場合は終了
                };
                elements.append(nextNounIndex) catch return null;
                nextIndex = nextNounIndex + 1; // 次の位置を更新
                break; // andの後の要素でListは終了
            } else {
                break; // andもcommaも見つからなければ終了
            }
        }

        if (elements.items.len < 2) {
            // 要素が2個未満の場合はリストではない
            return null;
        }

        const firstNode = SubNode{
            .startTokenIndex = firstIndex,
            .tag = SubNodeTag.NounPhrase,
            .data = SubAstStructs{ .Identifier = .{ .tokenIndex = firstIndex } },
        };
        const firstNodeIndex = self.addNode(firstNode, false) catch return null;

        var endNI: ?SubNodeIndex = null;

        for (elements.items[1..]) |elemIndex| {
            const elemNode = SubNode{
                .startTokenIndex = elemIndex,
                .tag = SubNodeTag.NounPhrase,
                .data = SubAstStructs{ .Identifier = .{ .tokenIndex = elemIndex } },
            };
            endNI = self.addNode(elemNode, false) catch return null;
        }

        const endNodeIndex = endNI orelse return null; // 最後の要素が存在しない場合はエラー

        const node = SubNode{ .startTokenIndex = index, .tag = SubNodeTag.NounPhrase, .data = SubAstStructs{ .RangeEnumeration = .{
            .start = firstNodeIndex,
            .end = endNodeIndex,
        } } };
        const nodeIndex = self.addNode(node, false) catch return null;
        return ParseResult{
            .nodes_index = nodeIndex,
            .next_token_index = nextIndex,
            .tag = SubNodeTag.NounPhrase,
        };
    }

    /// 接続詞をパースする
    pub fn parseConjunction(self: *SubParser, index: usize) ?ParseResult {
        const conjIndex = self.eatTokenKindList(index, &.{ .And, .But, .Otherwise, .Then }) orelse return null;
        std.debug.print("parseConjunction: index: {any}, conjIndex: {any}\n", .{ index, conjIndex });
        return self.createSimpleNode(conjIndex, .Conjunction) catch return null;
    }

    /// 従属接続詞をパースする
    pub fn parseSubordinatingConjunction(self: *SubParser, index: usize) ?ParseResult {
        const conjIndex = self.eatCategory(index, LexicalCategory.SubordinatingConjunction) orelse return null;
        return self.createSimpleNode(conjIndex, .SubordinatingConjunction) catch return null;
    }

    /// 分詞句をパースする
    pub fn parseParticiple(self: *SubParser, index: usize) ?ParseResult {
        // 分詞句をパースする
        // 例: running, walking など
        const participleIndex = self.eatCategory(index, .Participle) orelse return null;

        const participleVerbTag = replaceParticipleVerbKind(self.tokens.get(index)) orelse return null;

        const verbParticleIndex = self.eatCategory(participleIndex + 1, .VerbParticle);

        const participleNode = self.createSimpleNode(participleIndex, participleVerbTag) catch return null;

        const verbParticleNodeIndex = if (verbParticleIndex) |pi|
            // 句動詞のパース
            self.createSimpleNode(pi, .VerbParticle) catch return null
        else
            null;

        // buildMainWithOptionalNodeがOptionalノードを構築してくれる
        return self.buildMainWithOptionalNode(
            participleIndex,
            participleVerbTag,
            participleNode.nodes_index,
            if (verbParticleNodeIndex) |vp| vp.nodes_index else null,
            if (verbParticleIndex) |pi| pi + 1 else participleIndex + 1,
        ) catch return null;
    }

    /// 比較句をパースする
    pub fn parseComparativePhrase(self: *SubParser, index: usize) ?ParseResult {
        // more ~ than
        // the most ~ of
        // as ~ as
        // ~er than
        // the ~est of
        // のパターンのパースを行う

        // 比較級
        const moreIndex = self.eatTokenKind(index, Token.TokenKind.More);
        const comparativeIndex = self.eatCategory(index, LexicalCategory.Comparative);
        if (moreIndex) |mIdx| {
            return self.parseComparative(mIdx);
        }
        if (comparativeIndex) |cIdx| {
            return self.parseComparative(cIdx);
        }

        // 最上級
        const theIndex = self.eatTokenKind(index, Token.TokenKind.The);
        if (theIndex) |tIdx| {
            return self.parseSuperlative(tIdx);
        }

        // as ~ as のパターン
        const asIndex = self.eatTokenKind(index, Token.TokenKind.As);
        if (asIndex) |aIdx| {
            return self.parseEquateComparison(aIdx);
        }
        return null; // 比較句が見つからない場合はnull
    }

    /// 比較級のパース
    pub fn parseComparative(self: *SubParser, index: usize) ?ParseResult {
        const moreIndex = self.eatTokenKind(index, Token.TokenKind.More);
        const comparativeIndex = self.eatCategory(index, LexicalCategory.Comparative);
        if (moreIndex) |mIdx| {
            const normalComparableAdjectiveIndex = self.eatCategory(mIdx + 1, .ComparableAdjective) orelse return null;
            const thanIndex = self.eatTokenKind(normalComparableAdjectiveIndex + 1, Token.TokenKind.Than) orelse return null;
            const node = SubNode{
                .startTokenIndex = mIdx,
                .tag = SubNodeTag.ComparativePhrase,
                .data = SubAstStructs{
                    .OpAndVector = .{ .op = normalComparableAdjectiveIndex, .vector = thanIndex },
                },
            };
            const nodeIndex = self.addNode(node, false) catch return null;
            return ParseResult{
                .nodes_index = nodeIndex,
                .next_token_index = thanIndex + 1,
                .tag = SubNodeTag.ComparativePhrase,
            };
        } else if (comparativeIndex) |cIdx| {
            const thanIndex = self.eatTokenKind(cIdx + 1, Token.TokenKind.Than) orelse return null;
            const node = SubNode{
                .startTokenIndex = cIdx,
                .tag = SubNodeTag.ComparativePhrase,
                .data = SubAstStructs{
                    .OpAndVector = .{ .op = cIdx, .vector = thanIndex },
                },
            };
            const nodeIndex = self.addNode(node, false) catch return null;
            return ParseResult{
                .nodes_index = nodeIndex,
                .next_token_index = thanIndex + 1,
                .tag = SubNodeTag.ComparativePhrase,
            };
        }
        return null; // 比較級が見つからない場合はnull
    }

    /// 最上級のパース
    pub fn parseSuperlative(self: *SubParser, index: usize) ?ParseResult {
        // 最上級のパース
        // 例: the most beautiful, the fastest など
        const theIndex = self.eatTokenKind(index, Token.TokenKind.The) orelse return null;
        const superlativeIndex = self.eatCategory(theIndex + 1, LexicalCategory.Superlative);
        const mostIndex = self.eatTokenKind(theIndex + 1, Token.TokenKind.Most);

        if (superlativeIndex) |sIdx| {
            const ofIndex = self.eatTokenKind(sIdx + 1, Token.TokenKind.Of) orelse return null;

            const node = SubNode{
                .startTokenIndex = theIndex,
                .tag = SubNodeTag.ComparativePhrase,
                .data = SubAstStructs{
                    .OpAndVector = .{
                        .op = sIdx,
                        .vector = ofIndex,
                    },
                },
            };
            const nodeIndex = self.addNode(node, false) catch return null;

            return ParseResult{
                .nodes_index = nodeIndex,
                .next_token_index = ofIndex + 1,
                .tag = SubNodeTag.ComparativePhrase,
            };
        } else if (mostIndex) |mIdx| {
            // the most の形をパース
            const superlativeAdjectiveIndex = self.eatCategory(mIdx + 1, .ComparableAdjective) orelse return null;
            const ofIndex = self.eatTokenKind(superlativeAdjectiveIndex + 1, Token.TokenKind.Of) orelse return null;

            const node = SubNode{
                .startTokenIndex = theIndex,
                .tag = SubNodeTag.ComparativePhrase,
                .data = SubAstStructs{
                    .OpAndVector = .{
                        .op = superlativeAdjectiveIndex,
                        .vector = ofIndex,
                    },
                },
            };
            const nodeIndex = self.addNode(node, false) catch return null;

            return ParseResult{
                .nodes_index = nodeIndex,
                .next_token_index = ofIndex + 1,
                .tag = SubNodeTag.ComparativePhrase,
            };
        }
        return null; // 最上級が見つからない場合はnull
    }

    /// 同等比較のパース
    pub fn parseEquateComparison(self: *SubParser, index: usize) ?ParseResult {
        // as ~ as のパターンをパースする
        const asIndex = self.eatTokenKind(index, Token.TokenKind.As) orelse return null;
        const comparableAdjectiveIndex = self.eatCategory(asIndex + 1, .ComparableAdjective) orelse return null;
        const endAsIndex = self.eatTokenKind(comparableAdjectiveIndex + 1, Token.TokenKind.As) orelse return null;

        const node = SubNode{
            .startTokenIndex = index,
            .tag = SubNodeTag.ComparativePhrase,
            .data = SubAstStructs{ .OpAndVector = .{ .op = comparableAdjectiveIndex, .vector = endAsIndex } },
        };
        const nodeIndex = self.addNode(node, false) catch return null;

        return ParseResult{
            .nodes_index = nodeIndex,
            .next_token_index = endAsIndex + 1,
            .tag = SubNodeTag.ComparativePhrase,
        };
    }

    /// 数式の演算子をパースする
    pub fn parseMathOperator(self: *SubParser, index: usize) ?ParseResult {
        const opIndex = self.eatTokenKindList(index, &.{ .Plus, .Minus, .Multiply, .Divide, .And, .Or }) orelse return null;
        return self.createSimpleNode(opIndex, .MathOperator) catch return null;
    }

    fn buildMainWithOptionalNode(
        self: *SubParser,
        startIndex: usize,
        tag: SubNodeTag,
        mainIndex: SubNodeIndex,
        optionalIndex: ?SubNodeIndex,
        nextIndex: usize,
    ) !ParseResult {
        const node = SubNode{
            .startTokenIndex = startIndex,
            .tag = tag,
            .data = .{ .MainAndOptionalPhrase = .{
                .main = mainIndex,
                .optional = optionalIndex,
            } },
        };
        // Always set isRoot explicitly (always false here)
        const nodeIndex = try self.addNode(node, false);

        const next_token_index = nextIndex;
        return ParseResult{
            .nodes_index = nodeIndex,
            .next_token_index = next_token_index,
            .tag = tag,
        };
    }

    /// 複数の形容詞句の連続をまとめてパースし、範囲として返す
    fn parseAdjectiveList(self: *SubParser, index: usize) ?NodeIndexRangeResult {
        var currentIndex = index;
        const first = self.parseAdjectiveWithoutAddNodes(currentIndex) orelse return null;

        currentIndex = first.next_token_index;
        var adjectiveList = std.ArrayList(MainAndOptionalAndNextToken).init(self.allocator);

        defer adjectiveList.deinit();
        adjectiveList.append(first) catch return null;

        while (self.parseAdjectiveWithoutAddNodes(currentIndex)) |res| {
            adjectiveList.append(res) catch return null;

            currentIndex = res.next_token_index;
        }

        var firstNodeIndex: ?SubNodeIndex = null;
        var endNodeIndex: ?SubNodeIndex = null;

        for (adjectiveList.items, 0..) |item, idx| {
            const result = self.buildMainWithOptionalNode(
                item.startIndex,
                item.tag,
                item.main,
                item.optional,
                item.next_token_index,
            ) catch return null;

            const nodeIndex = result.nodes_index;
            if (idx == 0) {
                // 最初の要素のインデックスを保存
                firstNodeIndex = nodeIndex;
            }
            if (idx == adjectiveList.items.len - 1) {
                // 最後の要素のインデックスを保存
                endNodeIndex = nodeIndex;
            }
        }

        if (firstNodeIndex) |fIndex| {
            if (endNodeIndex) |eIndex| {
                // 最初と最後の要素が両方存在する場合
                const range = SubNodeIndexRange{
                    .start = fIndex,
                    .end = eIndex,
                };
                return NodeIndexRangeResult{
                    .range = range,
                    .next_token_index = currentIndex,
                };
            }
        }
        return null;
    }

    // 食べたtokenの位置を返す
    pub fn eatTokenKind(self: *SubParser, idx: usize, eatKind: Token.TokenKind) ?usize {
        if (idx >= self.tokens_len) return null;
        if (self.tokens.items(.kind)[idx] == eatKind) return idx;
        return null;
    }

    // 複数候補のTokenを検証して、次のtokenが候補の中にある場合位置を返す
    pub fn eatTokenKindList(self: *SubParser, idx: usize, eatKindList: []const Token.TokenKind) ?usize {
        if (idx >= self.tokens_len) return null;
        for (eatKindList) |eatKind| {
            if (self.tokens.items(.kind)[idx] == eatKind) return idx;
        }
        return null;
    }

    pub fn eatCategory(self: *SubParser, idx: usize, category: Token.LexicalCategory) ?usize {
        if (idx >= self.tokens_len) return null;
        if (Token.LexicalCategory.checkFlag(self.tokens.items(.category)[idx], category)) {
            return idx;
        }
        return null;
    }

    /// 複数候補のTokenのCategoryを検証して、次のtokenが候補の中にある場合位置を返す
    pub fn eatCategoryList(self: *SubParser, idx: usize, categoryList: []const Token.LexicalCategory) ?usize {
        if (idx >= self.tokens_len) return null;
        for (categoryList) |category| {
            if (Token.LexicalCategory.checkFlag(self.tokens.items(.category)[idx], category)) {
                return idx;
            }
        }
        return null;
    }

    pub fn setNode(self: *SubParser, index: usize, node: SubNode) void {
        // SubNodeを設定する
        // is_rootはデフォルトでfalseなので、必要に応じてsetRootNodeを使う
        self.sub_nodes.set(index, node);
    }
    /// Adds a SubNode to the parser, marking it as root if needed.
    /// Returns the SubNodeIndex, whose isRoot property will match the argument.
    pub fn addNode(self: *SubParser, node: SubNode, isRoot: bool) !SubNodeIndex {
        var true_node = node;
        true_node.is_root = isRoot;
        const index = self.sub_nodes.len;
        try self.sub_nodes.append(self.allocator, true_node);
        return SubNodeIndex{
            .index = index,
            .isRoot = isRoot,
        };
    }
};

/// tokenの動詞を変換する
fn replaceVerbKind(token: ast.TokenAndState) ?SubNodeTag {
    return switch (token.kind) {
        // Token.TokenKind.Define => SubNodeTag.DefineVerb,
        // Token.TokenKind.Suppose => SubNodeTag.SupposeVerb,
        Token.TokenKind.Let => SubNodeTag.LetVerb,
        else => {
            if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVVerb)) {
                return SubNodeTag.SVVerb;
            } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVOVerb)) {
                return SubNodeTag.SVOVerb;
            } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVCVerb)) {
                return SubNodeTag.SVCVerb;
            } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVOCVerb)) {
                return SubNodeTag.SVOCVerb;
            } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVOOVerb)) {
                return SubNodeTag.SVOOVerb;
            } else {
                return null;
            }
        },
    };
}

/// tokenの動詞から分詞の種類に変換する
pub fn replaceParticipleVerbKind(token: ast.TokenAndState) ?SubNodeTag {
    if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.Participle)) {
        if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVVerb)) {
            return SubNodeTag.SVParticiple;
        } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVOVerb)) {
            return SubNodeTag.SVOParticiple;
        } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVCVerb)) {
            return SubNodeTag.SVCParticiple;
        } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVOCVerb)) {
            return SubNodeTag.SVOCParticiple;
        } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVOOVerb)) {
            return SubNodeTag.SVOOParticiple;
        } else {
            return null;
        }
    }
    return null; // 分詞でない場合はnull
}

/// tokenの動詞から動名詞の種類に変換する
pub fn replaceGerundVerbKind(token: ast.TokenAndState) ?SubNodeTag {
    if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.Gerund)) {
        if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVVerb)) {
            return SubNodeTag.SVGerundVerb;
        } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVOVerb)) {
            return SubNodeTag.SVOGerundVerb;
        } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVCVerb)) {
            return SubNodeTag.SVCGerundVerb;
        } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVOCVerb)) {
            return SubNodeTag.SVOCGerundVerb;
        } else if (Token.LexicalCategory.checkFlag(token.category, Token.LexicalCategory.SVOOVerb)) {
            return SubNodeTag.SVOOGerundVerb;
        } else {
            return null;
        }
    }
    return null; // 動名詞でない場合はnull
}
