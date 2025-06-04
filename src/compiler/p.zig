const std = @import("std");

pub const Token = struct {
    kind: TokenKind,
    lexical_flag: u64, // ビットで品詞を表す
    loc: Loc,
    is_upper: bool,
    pos: Pos,

    pub const LexicalCategory = enum(u6) {
        /// 名詞（例: person, value, name）
        Noun = 0,
        /// 代名詞（例: he, it, they）
        Pronoun,
        /// 動詞（例: run, print, calculate）
        Verb,
        /// 準動詞（例: to run, running, printed）
        Verbal,
        /// 助動詞（例: can, will, should）
        AuxiliaryVerb,
        /// 形容詞（例: beautiful, valid, numeric）
        Adjective,
        /// 副詞（例: quickly, very, often）
        Adverb,
        /// 前置詞（例: in, on, of, from）
        Preposition,
        /// 等位接続詞（例: and, but, or）
        CoordinatingConjunction,
        /// 間投詞（例: oh!, hey!）
        Interjection,
        /// 限定詞（例: some, this, all）
        Determiner,
        /// 疑問詞（例: what, when, why, how）
        WhWord,
        /// 関係代名詞（例: who, that, which）
        RelativePronoun,
        /// 不定詞マーカー（to のみ）
        InfinitiveMarker,
        /// 従属接続詞（例: that, if, because）
        SubordinatingConjunction,
        /// 動名詞（例: running is fun の running）
        Gerund,
        /// 分詞（現在分詞・過去分詞）
        Participle,
        /// 句動詞パーティクル（例: up in look up）
        Particle,
        /// コピュラ動詞（例: be, become, seem）
        Copula,
        /// 不明（分類不能）
        Unknown,

        pub fn flagToArray(flag: u64) []LexicalCategory {
            const Self = @This();
            const max = comptime std.meta.fields(Self).len;
            var buffer: [max]Self = undefined;
            var i: usize = 0;
            var bit_index: u6 = 0;

            while (bit_index < max) : (bit_index += 1) {
                if ((flag & (@as(u64, 1) << bit_index)) != 0) {
                    buffer[i] = std.meta.intToEnum(Self, bit_index) catch continue;
                    i += 1;
                }
            }

            return buffer[0..i];
        }

        pub inline fn checkFlag(flag: u64, category: LexicalCategory) bool {
            return (flag & (@as(u64, 1) << @intFromEnum(category))) != 0;
        }

        pub inline fn getFlag(category: LexicalCategory) u64 {
            return @as(u64, 1) << @intFromEnum(category);
        }
    };

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const Pos = struct {
        line: usize,
        column: usize,
        line_offset: usize,
    };

    pub const TokenKind = enum {
        // Pronouns
        I,
        We,
        You,
        // Articles / Determiners
        A,
        An,
        // Basic verbs
        Let,
        Print,
        // Definition & control verbs
        Define,
        Call,
        Create,
        Give,
        Finish,
        Stop,
        Keep,
        Be,
        Do,
        Returns,
        Use,
        // Copula verbs
        Is,
        Are,
        // Structural keywords
        Function,
        Called,
        With,
        Parameters,
        As,
        Back,
        Being,
        Repeating,
        Sequence,
        Until,
        Then,
        Entity,
        Fields,
        Kept,
        Inside,
        Strict,
        Type,
        Checking,
        For,
        Common,
        All,
        These,
        Values,
        This,
        Creation,
        Of,
        That,
        Each,
        In,
        To,
        Through,
        Go,
        The,
        Everything,
        // Literals & Identifiers
        Identifier,
        IntegerLiteral,
        FloatLiteral,
        StringLiteral,
        // Operators
        Plus,
        Minus,
        Multiply,
        Divide,
        // Delimiters
        Comma,
        Semicolon,
        ParenOpen,
        ParenClose,
        EOF,
        // Error tokens
        DOUBLE_SLASH_COMMENT_ERROR,
        SLASH_ASTERISK_COMMENT_ERROR,
        ASTERISK_SLASH_COMMENT_ERROR,
        COLON_EQUAL_ASSIGNMENT_ERROR,
        Error,
    };

    pub const TokenInfo = struct {
        kind: TokenKind,
        flag: u64,
    };

    pub const keywords = std.StaticStringMap(TokenInfo).initComptime(.{
        // Pronouns
        // i : TokenKind.I, LexicalCategory.Pronoun
        .{ "i", TokenInfo{ .kind = .I, .flag = LexicalCategory.getFlag(.Pronoun) } },
        // we : TokenKind.We, LexicalCategory.Pronoun
        .{ "we", TokenInfo{ .kind = .We, .flag = LexicalCategory.getFlag(.Pronoun) } },
        // you : TokenKind.You, LexicalCategory.Pronoun
        .{ "you", TokenInfo{ .kind = .You, .flag = LexicalCategory.getFlag(.Pronoun) } },
        // it : TokenKind.Identifier, LexicalCategory.Pronoun
        .{ "it", TokenInfo{ .kind = .Identifier, .flag = LexicalCategory.getFlag(.Pronoun) } },

        // Articles / Determiners
        // a : TokenKind.A, LexicalCategory.Determiner
        .{ "a", TokenInfo{ .kind = .A, .flag = LexicalCategory.getFlag(.Determiner) } },
        // an : TokenKind.An, LexicalCategory.Determiner
        .{ "an", TokenInfo{ .kind = .An, .flag = LexicalCategory.getFlag(.Determiner) } },

        // Basic verbs
        // let : TokenKind.Let, LexicalCategory.Verb|AuxiliaryVerb
        .{ "let", TokenInfo{ .kind = .Let, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.AuxiliaryVerb) } },
        // print : TokenKind.Print, LexicalCategory.Verb
        .{ "print", TokenInfo{ .kind = .Print, .flag = LexicalCategory.getFlag(.Verb) } },

        // Definition & control verbs
        // define : TokenKind.Define, LexicalCategory.Verb
        .{ "define", TokenInfo{ .kind = .Define, .flag = LexicalCategory.getFlag(.Verb) } },
        // call : TokenKind.Call, LexicalCategory.Verb
        .{ "call", TokenInfo{ .kind = .Call, .flag = LexicalCategory.getFlag(.Verb) } },
        // create : TokenKind.Create, LexicalCategory.Verb
        .{ "create", TokenInfo{ .kind = .Create, .flag = LexicalCategory.getFlag(.Verb) } },
        // give : TokenKind.Give, LexicalCategory.Verb
        .{ "give", TokenInfo{ .kind = .Give, .flag = LexicalCategory.getFlag(.Verb) } },
        // finish : TokenKind.Finish, LexicalCategory.Verb
        .{ "finish", TokenInfo{ .kind = .Finish, .flag = LexicalCategory.getFlag(.Verb) } },
        // stop : TokenKind.Stop, LexicalCategory.Verb
        .{ "stop", TokenInfo{ .kind = .Stop, .flag = LexicalCategory.getFlag(.Verb) } },
        // keep : TokenKind.Keep, LexicalCategory.Verb
        .{ "keep", TokenInfo{ .kind = .Keep, .flag = LexicalCategory.getFlag(.Verb) } },
        // do : TokenKind.Do, LexicalCategory.AuxiliaryVerb
        .{ "do", TokenInfo{ .kind = .Do, .flag = LexicalCategory.getFlag(.AuxiliaryVerb) } },
        // returns : TokenKind.Returns, LexicalCategory.Verb
        .{ "returns", TokenInfo{ .kind = .Returns, .flag = LexicalCategory.getFlag(.Verb) } },
        // use : TokenKind.Use, LexicalCategory.Verb
        .{ "use", TokenInfo{ .kind = .Use, .flag = LexicalCategory.getFlag(.Verb) } },

        // Copula verbs
        // is : TokenKind.Is, LexicalCategory.Copula
        .{ "is", TokenInfo{ .kind = .Is, .flag = LexicalCategory.getFlag(.Copula) } },
        // are : TokenKind.Are, LexicalCategory.Copula
        .{ "are", TokenInfo{ .kind = .Are, .flag = LexicalCategory.getFlag(.Copula) } },

        // Structural keywords
        // function : TokenKind.Function, LexicalCategory.Noun
        .{ "function", TokenInfo{ .kind = .Function, .flag = LexicalCategory.getFlag(.Noun) } },
        // called : TokenKind.Called, LexicalCategory.Verbal
        .{ "called", TokenInfo{ .kind = .Called, .flag = LexicalCategory.getFlag(.Verbal) } },
        // with : TokenKind.With, LexicalCategory.Preposition
        .{ "with", TokenInfo{ .kind = .With, .flag = LexicalCategory.getFlag(.Preposition) } },
        // parameters : TokenKind.Parameters, LexicalCategory.Noun
        .{ "parameters", TokenInfo{ .kind = .Parameters, .flag = LexicalCategory.getFlag(.Noun) } },
        // as : TokenKind.As, LexicalCategory.Preposition
        .{ "as", TokenInfo{ .kind = .As, .flag = LexicalCategory.getFlag(.Preposition) } },
        // back : TokenKind.Back, LexicalCategory.Adverb
        .{ "back", TokenInfo{ .kind = .Back, .flag = LexicalCategory.getFlag(.Adverb) } },
        // being : TokenKind.Being, LexicalCategory.Gerund
        .{ "being", TokenInfo{ .kind = .Being, .flag = LexicalCategory.getFlag(.Gerund) } },
        // repeating : TokenKind.Repeating, LexicalCategory.Gerund
        .{ "repeating", TokenInfo{ .kind = .Repeating, .flag = LexicalCategory.getFlag(.Gerund) } },
        // sequence : TokenKind.Sequence, LexicalCategory.Noun
        .{ "sequence", TokenInfo{ .kind = .Sequence, .flag = LexicalCategory.getFlag(.Noun) } },
        // until : TokenKind.Until, LexicalCategory.SubordinatingConjunction
        .{ "until", TokenInfo{ .kind = .Until, .flag = LexicalCategory.getFlag(.SubordinatingConjunction) } },
        // then : TokenKind.Then, LexicalCategory.Adverb
        .{ "then", TokenInfo{ .kind = .Then, .flag = LexicalCategory.getFlag(.Adverb) } },
        // entity : TokenKind.Entity, LexicalCategory.Noun
        .{ "entity", TokenInfo{ .kind = .Entity, .flag = LexicalCategory.getFlag(.Noun) } },
        // fields : TokenKind.Fields, LexicalCategory.Noun
        .{ "fields", TokenInfo{ .kind = .Fields, .flag = LexicalCategory.getFlag(.Noun) } },
        // kept : TokenKind.Kept, LexicalCategory.Participle
        .{ "kept", TokenInfo{ .kind = .Kept, .flag = LexicalCategory.getFlag(.Participle) } },
        // inside : TokenKind.Inside, LexicalCategory.Preposition
        .{ "inside", TokenInfo{ .kind = .Inside, .flag = LexicalCategory.getFlag(.Preposition) } },
        // strict : TokenKind.Strict, LexicalCategory.Adjective
        .{ "strict", TokenInfo{ .kind = .Strict, .flag = LexicalCategory.getFlag(.Adjective) } },
        // type : TokenKind.Type, LexicalCategory.Noun
        .{ "type", TokenInfo{ .kind = .Type, .flag = LexicalCategory.getFlag(.Noun) } },
        // checking : TokenKind.Checking, LexicalCategory.Gerund
        .{ "checking", TokenInfo{ .kind = .Checking, .flag = LexicalCategory.getFlag(.Gerund) } },
        // for : TokenKind.For, LexicalCategory.Preposition
        .{ "for", TokenInfo{ .kind = .For, .flag = LexicalCategory.getFlag(.Preposition) } },
        // common : TokenKind.Common, LexicalCategory.Adjective
        .{ "common", TokenInfo{ .kind = .Common, .flag = LexicalCategory.getFlag(.Adjective) } },
        // all : TokenKind.All, LexicalCategory.Determiner
        .{ "all", TokenInfo{ .kind = .All, .flag = LexicalCategory.getFlag(.Determiner) } },
        // these : TokenKind.These, LexicalCategory.Determiner
        .{ "these", TokenInfo{ .kind = .These, .flag = LexicalCategory.getFlag(.Determiner) } },
        // values : TokenKind.Values, LexicalCategory.Noun
        .{ "values", TokenInfo{ .kind = .Values, .flag = LexicalCategory.getFlag(.Noun) } },
        // this : TokenKind.This, LexicalCategory.Determiner
        .{ "this", TokenInfo{ .kind = .This, .flag = LexicalCategory.getFlag(.Determiner) } },
        // creation : TokenKind.Creation, LexicalCategory.Noun
        .{ "creation", TokenInfo{ .kind = .Creation, .flag = LexicalCategory.getFlag(.Noun) } },
        // of : TokenKind.Of, LexicalCategory.Preposition
        .{ "of", TokenInfo{ .kind = .Of, .flag = LexicalCategory.getFlag(.Preposition) } },
        // that : TokenKind.That, LexicalCategory.RelativePronoun|SubordinatingConjunction|Pronoun
        .{ "that", TokenInfo{ .kind = .That, .flag = LexicalCategory.getFlag(.RelativePronoun) | LexicalCategory.getFlag(.SubordinatingConjunction) | LexicalCategory.getFlag(.Pronoun) } },
        // each : TokenKind.Each, LexicalCategory.Determiner
        .{ "each", TokenInfo{ .kind = .Each, .flag = LexicalCategory.getFlag(.Determiner) } },
        // in : TokenKind.In, LexicalCategory.Preposition
        .{ "in", TokenInfo{ .kind = .In, .flag = LexicalCategory.getFlag(.Preposition) } },
        // to : TokenKind.To, LexicalCategory.InfinitiveMarker|Preposition
        .{ "to", TokenInfo{ .kind = .To, .flag = LexicalCategory.getFlag(.InfinitiveMarker) | LexicalCategory.getFlag(.Preposition) } },
        // through : TokenKind.Through, LexicalCategory.Preposition
        .{ "through", TokenInfo{ .kind = .Through, .flag = LexicalCategory.getFlag(.Preposition) } },
        // go : TokenKind.Go, LexicalCategory.Verb
        .{ "go", TokenInfo{ .kind = .Go, .flag = LexicalCategory.getFlag(.Verb) } },
        // the : TokenKind.The, LexicalCategory.Determiner
        .{ "the", TokenInfo{ .kind = .The, .flag = LexicalCategory.getFlag(.Determiner) } },
        // everything : TokenKind.Everything, LexicalCategory.Pronoun
        .{ "everything", TokenInfo{ .kind = .Everything, .flag = LexicalCategory.getFlag(.Pronoun) } },
    });

    pub fn get_keyword(original: []const u8) ?TokenInfo {
        if (original.len == 0) return null;

        const allocator = std.heap.page_allocator;

        const lower = allocator.alloc(u8, original.len) catch return null;
        defer allocator.free(lower);
        @memcpy(lower[1..], original[1..]);
        lower[0] = std.ascii.toLower(original[0]);
        return keywords.get(lower);
    }
};

pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,
    line_offset: usize,
    line: usize,
    start: usize,
    pos: Token.Pos,

    pub fn init(buffer: [:0]const u8) Tokenizer {
        const tokenizer = comptime Tokenizer{ .buffer = buffer, .index = 0, .start = 0, .line_offset = 0, .line = 1 };
        tokenizer.eat_next_valid_index();
        return tokenizer;
    }

    /// \nまで読んでいる前提で行う
    pub inline fn next_line(self: *Tokenizer) void {
        self.line += 1;
        self.line_offset = self.index;
    }

    pub inline fn get_pos(self: *Tokenizer) Token.Pos {
        return .{
            .line = self.line,
            .column = self.index - self.line_offset + 1,
            .line_offset = self.line_offset,
        };
    }

    inline fn eat_whitespace(self: *Tokenizer) void {
        while (true) {
            switch (self.buffer[self.index]) {
                ' ', '\t' => self.index += 1,
                '\n' => {
                    self.index += 1;
                    self.next_line();
                },
                else => break,
            }
        }
    }

    // pub fn next(self: *Tokenizer) Token {}
    pub fn next(self: *Tokenizer) Token {
        self.start = self.index;
        self.result.next_line(self.index);
        self.pos.current = self.index - self.pos.line_offset;
        self.pos = self.get_pos();
        defer self.eat_next_valid_index();
        return self.lexNormal();
    }

    pub fn lexNormal(self: *Tokenizer) Token {
        switch (self.buffer[self.index]) {
            0 => {
                if (self.index == self.buffer.len) {
                    return .{
                        .kind = .eof,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                    };
                } else {
                    return Token{
                        .kind = .Error,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = .Error,
                    };
                }
            },
            'a'...'z' => {
                self.index += 1;
            },
            '/' => {
                self.index += 1;
                if (self.buffer[self.index] == '/') {
                    // slashでのコメントは使えないというエラーを返す
                }
                if (self.buffer[self.index] == '*') {
                    // /* でのコメントは使えないというエラーを返す
                }
            },
            '*' => {
                self.index += 1;
                if (self.buffer[self.index] == '/') {
                    // */ でのコメントは使えないというエラーを返す
                }
            },
            ':' => {
                self.index += 1;
                if (self.buffer[self.index] == '=') {
                    // := での代入は使えないというエラーを返す
                }
            },
            '"' => {
                return self.lexString();
            },
            else => {},
        }
    }

    pub fn lexIdentifier(self: *Tokenizer) Token {
        while (true) {
            switch (self.buffer[self.index]) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => {
                    self.index += 1;
                },
                else => break,
            }
        }
        const keyword = Token.get_keyword(self.buffer[self.start..self.index]);
        const is_upper = std.ascii.isUpper(self.buffer[self.start]);
        if (keyword) |k| {
            return Token{
                .kind = k.kind,
                .lexical_flag = k.flag,
                .loc = .{
                    .start = self.start,
                    .end = self.index,
                },
                .is_upper = is_upper,
                .pos = self.pos,
            };
        }
        return .{
            .kind = .Identifier,
            .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
            .loc = .{
                .start = self.start,
                .end = self.index,
            },
            .is_upper = is_upper,
            .pos = self.pos,
        };
    }

    pub fn lexString(self: *Tokenizer) Token {
        self.index += 1;
        while (self.buffer[self.index] != '"' and self.buffer[self.index] != 0) {
            if (self.buffer[self.index] == '\\') {
                self.index += 2;
            } else {
                self.index += 1;
            }
        }
        if (self.buffer[self.index] == 0) {
            return .{
                .kind = .Error,
                .lexical_flag = 0,
                .loc = .{
                    .start = self.start,
                    .end = self.index,
                },
            };
        } else {
            self.index += 1;
            self.result.loc.end = self.index;
            self.result.kind = Token.Kind.StringLiteral;
            self.result.lexical_flag |= 1 << Token.LexicalCategory.Noun;
            return self.result;
        }
    }
};

test "get_keyword" {
    const t = Token.get_keyword("that");
    const T = Token.get_keyword("That");
    try std.testing.expect(t.?.kind == Token.TokenKind.That);
    try std.testing.expect(T.?.kind == Token.TokenKind.That);
}

test "LexicalCategory" {
    const t = Token.get_keyword("that");
    try std.testing.expect(t.?.kind == Token.TokenKind.That);
    try std.testing.expect(t.?.flag == Token.LexicalCategory.getFlag(.RelativePronoun) | Token.LexicalCategory.getFlag(.SubordinatingConjunction) | Token.LexicalCategory.getFlag(.Pronoun));
}

test "LexicalCategoryByFlag" {
    const t = Token.get_keyword("that");
    try std.testing.expect(t.?.kind == Token.TokenKind.That);
    try std.testing.expect(t.?.flag == Token.LexicalCategory.getFlag(.RelativePronoun) | Token.LexicalCategory.getFlag(.SubordinatingConjunction) | Token.LexicalCategory.getFlag(.Pronoun));
    const kinds = Token.LexicalCategory.flagToArray(t.?.flag);
    try std.testing.expect(kinds.len == 3);
    try std.testing.expect(kinds[0] == Token.LexicalCategory.Pronoun);
    try std.testing.expect(kinds[1] == Token.LexicalCategory.RelativePronoun);
    try std.testing.expect(kinds[2] == Token.LexicalCategory.SubordinatingConjunction);
}

test "LexicalCategoryCheckFlag" {
    const t = Token.get_keyword("that");
    try std.testing.expect(t.?.kind == Token.TokenKind.That);
    try std.testing.expect(t.?.flag == Token.LexicalCategory.getFlag(.RelativePronoun) | Token.LexicalCategory.getFlag(.SubordinatingConjunction) | Token.LexicalCategory.getFlag(.Pronoun));
    try std.testing.expect(Token.LexicalCategory.checkFlag(t.?.flag, Token.LexicalCategory.RelativePronoun));
    try std.testing.expect(Token.LexicalCategory.checkFlag(t.?.flag, Token.LexicalCategory.SubordinatingConjunction));
    try std.testing.expect(Token.LexicalCategory.checkFlag(t.?.flag, Token.LexicalCategory.Pronoun));
    try std.testing.expect(!Token.LexicalCategory.checkFlag(t.?.flag, Token.LexicalCategory.Verb));
}
