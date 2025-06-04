const tokenizer = @import("tokenizer.zig");
const ast = @import("./ast.zig");
const Token = tokenizer.Token;
const TokenAndStateList = ast.TokenAndStateList;
const std = @import("std");
const Error = ast.Error;
const LexicalCategory = Token.LexicalCategory;
const ThreeFlag = ast.ThreeFlag;

// ast kind
pub const ExprKind = enum(u4) {
    /// 主語（I, We, Thisなど）
    SubjectExpr = 0,

    /// SVの動詞（例: run, walk）
    SVVerbExpr,

    /// SVOの動詞（例: have, create）
    SVOVerbExpr,

    /// SVCの動詞（例: is, become）
    SVCVerbExpr,

    /// SVOCの動詞（例: make, call）
    SVOCVerbExpr,

    /// SVOOの動詞（例: give, send）
    SVOOVerbExpr,

    /// let専用の動詞（例: let）
    LetVerbExpr,

    /// suppose専用の動詞（例: suppose）
    SupposeVerbExpr,

    /// 名詞句（例: a book, my brother）
    NounPhraseExpr,

    /// 修飾句（副詞句、前置詞句、形容詞句など）
    ModifierExpr,

    /// 不明または未分類（エラー処理や暫定用）
    UnknownExpr,
};

/// verbの種類を表すenum
/// 実質文の種類
pub const VerbKind = enum(u4) {
    /// SVの動詞（例: run, walk）
    SVVerbExpr = 0,

    /// SVOの動詞（例: have, create）
    SVOVerbExpr,

    /// SVCの動詞（例: is, become）
    SVCVerbExpr,

    /// SVOCの動詞（例: make, call）
    SVOCVerbExpr,

    /// SVOOの動詞（例: give, send）
    SVOOVerbExpr,

    /// let専用の動詞（例: let）
    LetVerbExpr,

    /// suppose専用の動詞（例: suppose）
    SupposeVerbExpr,
};

pub const SubASTNode = union(enum) {
    Subject: struct {
        tokenIndex: usize,
    },

    Verb: struct {
        verbKind: VerbKind,
        tokenIndex: usize,
    },

    NounPhrase: struct {
        startIndex: usize,
        endIndex: usize,
    },

    Modifier: struct {
        startIndex: usize,
        endIndex: usize,
    },

    Unknown: struct {
        errorIndex: usize,
    },
};

pub const Parser = struct {
    tokens: TokenAndStateList,
    tokens_len: usize,
    errors: std.ArrayList(Error),
    pub const parseReturn = struct {
        startTokenIndex: usize,
        endTokenIndex: usize,
        exprKind: ExprKind,
    };

    pub fn init(tokens: TokenAndStateList) Parser {
        return .{
            .tokens = tokens,
            .tokens_len = tokens.len,
            .errors = std.ArrayList(error.Error).init(std.heap.page_allocator),
        };
    }

    pub fn parseSubject(self: *Parser, index: usize) ?parseReturn {
        const subjectIndex = self.eatTokenKindList(index, .{ .I, .We, .You });
        if (subjectIndex) |sindex| {
            self.setCheckedFlag(sindex, sindex + 1);
            return .{
                .startTokenIndex = sindex,
                .endTokenIndex = sindex + 1,
                .exprKind = ExprKind.SubjectExpr,
            };
        }
        return null;
    }

    /// Tokenを startIndex から endIndex まで (両端を含む) Checked にする
    pub fn setCheckedFlag(self: *Parser, startIndex: usize, endIndex: usize) void {
        if (startIndex >= self.tokens.len) return;
        const last: usize = @min(endIndex, self.tokens.len);

        var i: usize = startIndex;
        while (i < last) : (i += 1) {
            self.tokens.items(.state)[i] = ThreeFlag.getFlag(.Confirmed);
        }
    }

    // 食べたtokenの位置を返す
    pub fn eatTokenKind(self: *Parser, idx: usize, eatKind: Token.TokenKind) ?usize {
        if (idx >= self.tokens_len) return null;
        if (self.tokens(.kind)[idx] == eatKind) return idx;
    }

    // 複数候補のTokenを検証して、次のtokenが候補の中にある場合位置を返す
    pub fn eatTokenKindList(self: *Parser, idx: usize, eatKindList: []const Token.TokenKind) ?usize {
        if (idx >= self.tokens_len) return null;
        for (eatKindList, 0..) |eatKind, offset| {
            const nextIdx = idx + offset;
            if (nextIdx >= self.tokens_len) return null;
            if (self.tokens(.kind)[nextIdx] == eatKind) return nextIdx;
        }
    }

    pub fn eatCategory(self: *Parser, idx: usize, category: Token.LexicalCategory) ?usize {
        if (idx >= self.tokens_len) return null;
        if (Token.LexicalCategory.checkFlag(self.tokens[idx].category, category)) {
            return idx;
        }
    }

    /// 複数候補のTokenのCategoryを検証して、次のtokenが候補の中にある場合位置を返す
    pub fn eatCategoryList(self: *Parser, idx: usize, categoryList: []const Token.LexicalCategory) ?usize {
        if (idx >= self.tokens_len) return null;
        for (categoryList, 0..) |category, offset| {
            const nextIdx = idx + offset;
            if (nextIdx >= self.tokens_len) return null;
            if (Token.LexicalCategory.checkFlag(self.tokens.items(.category)[nextIdx], category)) {
                return nextIdx;
            }
        }
    }

    fn expectTokens(self: *Parser, startIdx: usize, expectedTokens: []const Token.TokenKind) ?usize {
        for (expectedTokens, 0..) |expected, offset| {
            const idx = startIdx + offset;
            if (idx >= self.tokens.len or self.tokens.items(.kind)[idx] != expected) {
                return null;
            }
        }
        return startIdx + expectedTokens.len;
    }

    fn expectTokenCategory(self: *Parser, startIdx: usize, expectedCategories: Token.LexicalCategory) ?usize {
        for (expectedCategories, 0..) |expected, offset| {
            const idx = startIdx + offset;
            if (idx >= self.tokens.len or Token.LexicalCategory.checkFlag(self.tokens.items(.category)[idx], expected)) {
                return null;
            }
        }
        return startIdx + expectedCategories.len;
    }
};
