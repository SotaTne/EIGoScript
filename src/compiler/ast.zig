const std = @import("std");
const tokenizer = @import("./tokenizer.zig");
const Allocator = std.mem.Allocator;
const Token = tokenizer.Token;
const Tokenizer = tokenizer.Tokenizer;
pub const TokenAndStateList = std.MultiArrayList(TokenAndState);
const parser = @import("./parser.zig");

pub const ThreeFlag = enum(u2) {
    Unprocessed = 0,
    /// PreCheckedにてチェックされたもの
    Checked,
    /// checkedでその分の起点となっているもの I defineではIがPChecked, We defineではWeがPChecked
    PChecked,
    /// その範囲がパースされたもの
    Confirmed,

    pub inline fn getFlag(category: ThreeFlag) u4 {
        return @as(u4, 1) << @intFromEnum(category);
    }
    pub inline fn checkFlag(flag: u4, category: ThreeFlag) bool {
        return (flag & @as(u4, 1) << @intFromEnum(category)) != 0;
    }
    pub inline fn createFlag(category: ThreeFlag) u4 {
        return @as(u4, 1) << @intFromEnum(category);
    }

    pub fn flagToArray(flag: u4, allocator: std.mem.Allocator) !std.ArrayList(ThreeFlag) {
        const Self = @This();
        const max: u2 = comptime std.meta.fields(Self).len - 1; // 4はu4なのでu2にするために-1
        var bit_index: u2 = 0;
        var array = std.ArrayList(Self).init(allocator);
        errdefer array.deinit();

        while (bit_index <= max) : (if (bit_index < max) {
            bit_index += 1;
        } else {
            break;
        }) {
            if ((flag & @as(u4, 1) << bit_index) != 0) {
                const value = std.meta.intToEnum(Self, bit_index) catch continue;
                try array.append(value);
            }
        }
        return array;
    }
};

/// 文構造や句・節・特殊文を網羅したパーサ用Kind（ExprStmt/Kind/Nodeなど）enum例
pub const ExprKind = enum(u4) {
    /// 主語（I, We, This ...）
    SubjectExpr = 0,

    /// SV型の文（主語＋動詞）
    SVExpr,
    /// SVO型の文（主語＋動詞＋目的語）
    SVOExpr,
    /// SVC型の文（主語＋動詞＋補語）
    SVCExpr,
    /// SVOC型の文（主語＋動詞＋目的語＋補語）
    SVOCExpr,
    /// SVOO型の文（主語＋動詞＋目的語＋目的語）
    SVOOExpr,

    /// SVO型の動詞
    SVOVerbExpr,
    /// SVC型の動詞
    SVCVerbExpr,
    /// SVOC型の動詞
    SVOCVerbExpr,
    /// SVOO型の動詞
    SVOOVerbExpr,
    /// SV型の動詞
    SVVerbExpr,

    /// Let 構文（使役文） S let O V
    LetExpr,
    /// let の動詞種別
    LetVerbExpr,

    /// Suppose構文（仮定文）
    SupposeExpr,
    /// suppose の動詞種別
    SupposeVerbExpr,

    /// 不定詞句 (to + 動詞)
    ToClauseExpr,
    /// that節
    ThatClauseExpr,

    /// 修飾語（副詞句/句修飾, 前置詞句等）
    ModifierExpr,

    /// 名詞句
    NounPhraseExpr,
    /// 動詞句
    VerbPhraseExpr,

    /// 節（汎用）…拡張用
    ClauseExpr,

    /// 文全体（トップレベルノード）
    SentenceExpr,
};

pub const TokenAndState = struct {
    kind: Token.TokenKind,
    category: u64,
    is_upper: bool,
    pos: Token.Pos,
    loc: Token.Loc,
    state: u4,
    check_count: u8,
    contentsHash: ?u64 = null,
};

pub const Error = error{
    InvalidDefine,
    UnexpectedEndOfFile,
    UnexpectedToken,
    // …etc…
};

pub fn getTokenList(allocator: Allocator, buffer: [:0]const u8) !TokenAndStateList {
    var lexer = Tokenizer.init(buffer);
    var tokenAndStates: TokenAndStateList = TokenAndStateList{};

    while (true) {
        const token = lexer.next();
        if (token.kind == Token.TokenKind.EOF) break;
        try tokenAndStates.append(allocator, TokenAndState{
            .kind = token.kind,
            .category = token.lexical_flag,
            .is_upper = token.is_upper,
            .pos = token.pos,
            .loc = token.loc,
            .state = ThreeFlag.createFlag(ThreeFlag.Unprocessed),
            .check_count = 0,
            .contentsHash = token.contentsHash,
        });
    }
    return tokenAndStates;
}

test "testGetTokenList" {
    const allocator = std.testing.allocator;
    const buffer: [:0]const u8 = "hello world";
    var tokens = getTokenList(allocator, buffer) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer tokens.deinit(allocator);

    for (tokens.items(.kind), 0..) |kind, i| {
        std.debug.print("Token {}: {}\n", .{ i, kind });
    }
}

test "testFlagToArray" {
    const allocator = std.testing.allocator;
    const flag = ThreeFlag.getFlag(ThreeFlag.Unprocessed) | ThreeFlag.getFlag(ThreeFlag.Checked);
    var array = ThreeFlag.flagToArray(flag, allocator) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer array.deinit();

    for (array.items, 0..) |value, i| {
        std.debug.print("Flag {}: {}\n", .{ i, value });
    }
}
