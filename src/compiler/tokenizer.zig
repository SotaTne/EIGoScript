const std = @import("std");
const Fnv1a_64 = std.hash.Fnv1a_64;

pub const Token = struct {
    kind: TokenKind,
    lexical_flag: u64, // ビットで品詞を表す
    loc: Loc,
    is_upper: bool = false,
    pos: Pos,
    contentsHash: ?u64 = null,

    pub const LexicalCategory = enum(u6) {
        /// 名詞（例: person, value, name）
        Noun = 0,
        /// 代名詞（例: he, it, they）
        Pronoun,
        /// 動詞（例: run, print, calculate）
        Verb,

        /// （例: to run, running, printed）
        // Verbal,
        // /// 助動詞（例: can, will, should）
        // AuxiliaryVerb,

        /// 形容詞（例: beautiful, valid, numeric）
        Adjective,
        /// 副詞（例: quickly, very, often）
        Adverb,
        /// 前置詞（例: in, on, of, from）
        Preposition,
        /// 等位接続詞（例: and, but, or）
        CoordinatingConjunction,

        // /// 間投詞（例: oh!, hey!）
        // Interjection,
        // /// 限定詞（例: some, this, all）
        // Determiner,

        /// 冠詞（例: a, an, the）
        Article,

        // /// 疑問詞（例: what, when, why, how）
        // WhWord,

        // /// 関係代名詞（例: who, that, which）
        // RelativePronoun,

        /// 不定詞マーカー（to のみ）
        InfinitiveMarker,
        /// 従属接続詞（例: that, if, because）
        SubordinatingConjunction,
        /// 動名詞（例: running is fun の running）
        Gerund,
        // /// 分詞（現在分詞・過去分詞）
        Participle,

        /// 句動詞パーティクル（例: up in look up）
        // Particle,

        /// コピュラ動詞（例: be, become, seem）
        Copula,
        /// 仮定マーカー動詞 suppose
        // Conditional,
        /// 使役動詞 let の専用品詞 (S Let O V)
        LetVerb,
        /// `Suppose` 専用動詞品詞
        // SupposeVerb,
        /// 句動詞 (give backのback, look upのupなど)
        VerbParticle,
        /// 演算子（例: +, -, *, /）
        Operator,
        /// 句読点（例: ., ,, ;, :）
        Punctuation,
        /// 否定後
        Negation,
        /// SVの動詞
        SVVerb,
        /// SVOの動詞
        SVOVerb,
        /// SVCの動詞
        SVCVerb,
        /// SVOCの動詞
        SVOCVerb,
        /// SVOOの動詞
        SVOOVerb,
        /// 比較級 comparative（例: bigger, smaller）
        Comparative,
        /// 最上級 superlative（例: biggest, smallest）
        Superlative,
        /// 比較可能な形容詞 big smallなど
        ComparableAdjective,
        /// 不明（分類不能）
        Unknown,

        pub fn flagToArray(flag: u64, allocator: std.mem.Allocator) !std.ArrayList(LexicalCategory) {
            const Self = @This();
            const max = comptime std.meta.fields(Self).len;
            //var buffer: [max]Self = undefined;
            var array = std.ArrayList(Self).init(allocator);
            errdefer array.deinit();

            var bit_index: u6 = 0;
            while (bit_index < max) : (bit_index += 1) {
                if ((flag & (@as(u64, 1) << bit_index)) != 0) {
                    const value = std.meta.intToEnum(Self, bit_index) catch continue;
                    try array.append(value);
                }
            }

            return array;
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
        It,
        // Articles / Determiners
        A,
        An,
        // Basic verbs
        Let,
        Print,
        // Definition & control verbs
        Define,
        Call,
        // Create,
        Give,
        Finish,
        Stop,
        Keep,
        Be,
        Do,
        Returns,
        // Use,
        Takes,

        Following,

        // Copula verbs
        Is,
        Are,

        // Structural keywords
        Function,
        Verb,
        Called,
        With,
        Parameters,
        As,
        Back,
        // Being,
        Repeating,
        Sequence,
        Until,
        Then,
        // Entity,
        // Fields,
        // Kept,
        // Inside,
        // Strict,
        // Type,
        // Checking,
        // For,
        // Common,
        All,
        // These,
        // Values,
        // This,
        // Creation,
        Of,
        That,
        // Each,
        // In,
        To,
        Through,
        Go,
        Out,
        The,
        Everything,
        // Suppose,
        Explanation,
        // What,
        // When,
        // Where,
        // Who,
        // Why,
        // How,
        // Which,
        // Whose,
        // Whom,

        Bigger,
        Smaller,
        Big,
        Small,
        Biggest,
        Smallest,
        More,
        Most,
        // Less,
        Than,
        Not,
        No,
        // Those,
        But,
        // If,
        Otherwise,
        And,
        Or,

        // 特殊な形容詞
        SV,
        SVO,
        SVC,
        SVOC,
        SVOO,

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
        Colon,
        Period,
        Comma,
        Semicolon,
        QuestionMark,
        ParenOpen,
        ParenClose,

        COMMENT,
        EOF,
        // Error tokens
        DOUBLE_SLASH_COMMENT_ERROR,
        SLASH_ASTERISK_COMMENT_ERROR,
        ASTERISK_SLASH_COMMENT_ERROR,
        HASH_COMMENT_ERROR,
        COLON_EQUAL_ASSIGNMENT_ERROR,

        FLOAT_LITERAL_ERROR,
        INTEGER_LITERAL_ERROR,
        STRING_CLOSE_ERROR,

        COLON_COLON_OPERATOR_ERROR,
        DOT_DOT_OPERATOR_ERROR,
        DOLLAR_SIGN_OPERATOR_ERROR,
        Error,
    };
    pub const TokenInfo = struct {
        kind: TokenKind,
        flag: u64,
    };

    pub const keywords = std.StaticStringMap(TokenInfo).initComptime(.{
        // Pronouns
        // i : TokenKind.I, LexicalCategory.Pronoun
        .{ "i", TokenInfo{ .kind = .I, .flag = LexicalCategory.getFlag(.Pronoun) | LexicalCategory.getFlag(.Noun) } },
        // we : TokenKind.We, LexicalCategory.Pronoun
        .{ "we", TokenInfo{ .kind = .We, .flag = LexicalCategory.getFlag(.Pronoun) | LexicalCategory.getFlag(.Noun) } },
        // you : TokenKind.You, LexicalCategory.Pronoun
        .{ "you", TokenInfo{ .kind = .You, .flag = LexicalCategory.getFlag(.Pronoun) | LexicalCategory.getFlag(.Noun) } },
        // it : TokenKind.Identifier, LexicalCategory.Pronoun
        .{ "it", TokenInfo{ .kind = .It, .flag = LexicalCategory.getFlag(.Pronoun) | LexicalCategory.getFlag(.Noun) } },

        // Articles / Determiners
        // a : TokenKind.A, LexicalCategory.Determiner
        .{ "a", TokenInfo{ .kind = .A, .flag = LexicalCategory.getFlag(.Article) } },
        // an : TokenKind.An, LexicalCategory.Determiner
        .{ "an", TokenInfo{ .kind = .An, .flag = LexicalCategory.getFlag(.Article) } },

        // Basic verbs
        // let : TokenKind.Let, LexicalCategory.Verb|AuxiliaryVerb|LetVerb
        .{ "let", TokenInfo{ .kind = .Let, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.LetVerb) } },
        // print : TokenKind.Print, LexicalCategory.Verb|SVOVerb
        .{ "print", TokenInfo{ .kind = .Print, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOVerb) } },

        // Definition & control verbs
        // define : TokenKind.Define, LexicalCategory.Verb|SVOVerb
        .{ "define", TokenInfo{ .kind = .Define, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOVerb) } },
        // call : TokenKind.Call, LexicalCategory.Verb|SVOVerb
        .{ "call", TokenInfo{ .kind = .Call, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOVerb) } },
        // create : TokenKind.Create, LexicalCategory.Verb|SVOVerb
        // .{ "create", TokenInfo{ .kind = .Create, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOVerb) } },
        // give : TokenKind.Give, LexicalCategory.Verb|SVOOVerb
        .{ "give", TokenInfo{ .kind = .Give, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOVerb) } },
        // finish : TokenKind.Finish, LexicalCategory.Verb|SVVerb
        .{ "finish", TokenInfo{ .kind = .Finish, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVVerb) } },
        // stop : TokenKind.Stop, LexicalCategory.Verb|SVVerb
        .{ "stop", TokenInfo{ .kind = .Stop, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVVerb) } },
        // keep : TokenKind.Keep, LexicalCategory.Verb|SVVerb
        .{ "keep", TokenInfo{ .kind = .Keep, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVVerb) } },
        // do : TokenKind.Do, LexicalCategory.AuxiliaryVerb|SVOVerb
        .{ "do", TokenInfo{ .kind = .Do, .flag = LexicalCategory.getFlag(.SVOVerb) } },
        // returns : TokenKind.Returns, LexicalCategory.Verb|SVOVerb
        .{ "returns", TokenInfo{ .kind = .Returns, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOVerb) } },
        // use : TokenKind.Use, LexicalCategory.Verb|SVOVerb
        // .{ "use", TokenInfo{ .kind = .Use, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOVerb) } },
        // takes : TokenKind.Takes, LexicalCategory.Verb|SVOVerb
        .{ "takes", TokenInfo{ .kind = .Takes, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOVerb) } },

        // Copula verbs
        // is : TokenKind.Is, LexicalCategory.Copula|SVCVerb
        .{ "is", TokenInfo{ .kind = .Is, .flag = LexicalCategory.getFlag(.Copula) | LexicalCategory.getFlag(.SVCVerb) | LexicalCategory.getFlag(.Verb) } },
        // are : TokenKind.Are, LexicalCategory.Copula|SVCVerb
        .{ "are", TokenInfo{ .kind = .Are, .flag = LexicalCategory.getFlag(.Copula) | LexicalCategory.getFlag(.SVCVerb) | LexicalCategory.getFlag(.Verb) } },
        // be : TokenKind.Be, LexicalCategory.Copula|SVCVerb
        .{ "be", TokenInfo{ .kind = .Be, .flag = LexicalCategory.getFlag(.Copula) | LexicalCategory.getFlag(.SVCVerb) | LexicalCategory.getFlag(.Verb) } },

        // Structural keywords
        // function : TokenKind.Function, LexicalCategory.Noun
        .{ "function", TokenInfo{ .kind = .Function, .flag = LexicalCategory.getFlag(.Noun) } },
        // verb : TokenKind.Verb, LexicalCategory.Noun
        .{ "verb", TokenInfo{ .kind = .Verb, .flag = LexicalCategory.getFlag(.Noun) } },
        // called : TokenKind.Called, LexicalCategory.Verbal
        .{ "called", TokenInfo{ .kind = .Called, .flag = LexicalCategory.getFlag(.Participle) | LexicalCategory.getFlag(.SVCVerb) } },
        // with : TokenKind.With, LexicalCategory.Preposition
        .{ "with", TokenInfo{ .kind = .With, .flag = LexicalCategory.getFlag(.Preposition) } },
        // parameters : TokenKind.Parameters, LexicalCategory.Noun
        .{ "parameters", TokenInfo{ .kind = .Parameters, .flag = LexicalCategory.getFlag(.Noun) } },
        // as : TokenKind.As, LexicalCategory.Preposition
        .{ "as", TokenInfo{ .kind = .As, .flag = LexicalCategory.getFlag(.Preposition) } },
        // back : TokenKind.Back, LexicalCategory.Adverb
        .{ "back", TokenInfo{ .kind = .Back, .flag = LexicalCategory.getFlag(.Adverb) | LexicalCategory.getFlag(.VerbParticle) } },
        // being : TokenKind.Being, LexicalCategory.Gerund
        // .{ "being", TokenInfo{ .kind = .Being, .flag = LexicalCategory.getFlag(.Gerund) | LexicalCategory.getFlag(.SVCVerb) } },
        // repeating : TokenKind.Repeating, LexicalCategory.Gerund
        .{ "repeating", TokenInfo{ .kind = .Repeating, .flag = LexicalCategory.getFlag(.Gerund) | LexicalCategory.getFlag(.SVOVerb) } },
        // sequence : TokenKind.Sequence, LexicalCategory.Noun
        .{ "sequence", TokenInfo{ .kind = .Sequence, .flag = LexicalCategory.getFlag(.Noun) } },
        // until : TokenKind.Until, LexicalCategory.SubordinatingConjunction
        .{ "until", TokenInfo{ .kind = .Until, .flag = LexicalCategory.getFlag(.SubordinatingConjunction) } },
        // then : TokenKind.Then, LexicalCategory.CoordinatingConjunction
        .{ "then", TokenInfo{ .kind = .Then, .flag = LexicalCategory.getFlag(.CoordinatingConjunction) } },
        // entity : TokenKind.Entity, LexicalCategory.Noun
        // .{ "entity", TokenInfo{ .kind = .Entity, .flag = LexicalCategory.getFlag(.Noun) } },
        // fields : TokenKind.Fields, LexicalCategory.Noun
        // .{ "fields", TokenInfo{ .kind = .Fields, .flag = LexicalCategory.getFlag(.Noun) } },
        // kept : TokenKind.Kept, LexicalCategory.Participle
        // .{ "kept", TokenInfo{ .kind = .Kept, .flag = LexicalCategory.getFlag(.Participle) } },
        // inside : TokenKind.Inside, LexicalCategory.Preposition
        // .{ "inside", TokenInfo{ .kind = .Inside, .flag = LexicalCategory.getFlag(.Preposition) } },
        // strict : TokenKind.Strict, LexicalCategory.Adjective
        // .{ "strict", TokenInfo{ .kind = .Strict, .flag = LexicalCategory.getFlag(.Adjective) } },
        // type : TokenKind.Type, LexicalCategory.Noun
        // .{ "type", TokenInfo{ .kind = .Type, .flag = LexicalCategory.getFlag(.Noun) } },
        // checking : TokenKind.Checking, LexicalCategory.Gerund
        // .{ "checking", TokenInfo{ .kind = .Checking, .flag = LexicalCategory.getFlag(.Gerund) } },
        // for : TokenKind.For, LexicalCategory.Preposition
        // .{ "for", TokenInfo{ .kind = .For, .flag = LexicalCategory.getFlag(.Preposition) } },
        // common : TokenKind.Common, LexicalCategory.Adjective
        // .{ "common", TokenInfo{ .kind = .Common, .flag = LexicalCategory.getFlag(.Adjective) } },
        // all : TokenKind.All, LexicalCategory.Determiner
        .{ "all", TokenInfo{ .kind = .All, .flag = LexicalCategory.getFlag(.Adjective) | LexicalCategory.getFlag(.Noun) } },
        // these : TokenKind.These, LexicalCategory.Determiner|Pronoun
        // .{ "these", TokenInfo{ .kind = .These, .flag = LexicalCategory.getFlag(.Determiner) | LexicalCategory.getFlag(.Pronoun) } },
        // values : TokenKind.Values, LexicalCategory.Noun
        // .{ "values", TokenInfo{ .kind = .Values, .flag = LexicalCategory.getFlag(.Noun) } },
        // this : TokenKind.This, LexicalCategory.Determiner|Pronoun
        // .{ "this", TokenInfo{ .kind = .This, .flag = LexicalCategory.getFlag(.Determiner) | LexicalCategory.getFlag(.Pronoun) } },
        // creation : TokenKind.Creation, LexicalCategory.Noun
        // .{ "creation", TokenInfo{ .kind = .Creation, .flag = LexicalCategory.getFlag(.Noun) } },
        // of : TokenKind.Of, LexicalCategory.Preposition
        .{ "of", TokenInfo{ .kind = .Of, .flag = LexicalCategory.getFlag(.Preposition) } },
        // that : TokenKind.That, LexicalCategory.RelativePronoun|SubordinatingConjunction|Pronoun|Determiner
        .{ "that", TokenInfo{ .kind = .That, .flag = LexicalCategory.getFlag(.Pronoun) } },
        // each : TokenKind.Each, LexicalCategory.Determiner
        // .{ "each", TokenInfo{ .kind = .Each, .flag = LexicalCategory.getFlag(.Determiner) } },
        // in : TokenKind.In, LexicalCategory.Preposition
        // .{ "in", TokenInfo{ .kind = .In, .flag = LexicalCategory.getFlag(.Preposition) } },
        // to : TokenKind.To, LexicalCategory.InfinitiveMarker|Preposition
        .{ "to", TokenInfo{ .kind = .To, .flag = LexicalCategory.getFlag(.InfinitiveMarker) | LexicalCategory.getFlag(.Preposition) } },
        // through : TokenKind.Through, LexicalCategory.Preposition
        .{ "through", TokenInfo{ .kind = .Through, .flag = LexicalCategory.getFlag(.Preposition) } },
        // go : TokenKind.Go, LexicalCategory.Verb
        .{ "go", TokenInfo{ .kind = .Go, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOVerb) } },
        // out 将来的に、名詞や副詞を追加する可能性あり
        .{ "out", TokenInfo{ .kind = .Out, .flag = LexicalCategory.getFlag(.VerbParticle) } },
        // the : TokenKind.The, LexicalCategory.Determiner
        .{ "the", TokenInfo{ .kind = .The, .flag = LexicalCategory.getFlag(.Article) } },
        // everything : TokenKind.Everything, LexicalCategory.Pronoun
        .{ "everything", TokenInfo{ .kind = .Everything, .flag = LexicalCategory.getFlag(.Pronoun) } },
        // suppose : TokenKind.Suppose, LexicalCategory.Verb|Conditional|SupposeVerb
        // .{ "suppose", TokenInfo{ .kind = .Suppose, .flag = LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.Conditional) | LexicalCategory.getFlag(.SupposeVerb) } },
        // but : TokenKind.But, LexicalCategory.CoordinatingConjunction
        .{ "but", TokenInfo{ .kind = .But, .flag = LexicalCategory.getFlag(.CoordinatingConjunction) } },
        // if : TokenKind.If, LexicalCategory.SubordinatingConjunction
        // .{ "if", TokenInfo{ .kind = .If, .flag = LexicalCategory.getFlag(.SubordinatingConjunction) } },
        // otherwise : TokenKind.Otherwise, LexicalCategory.Adverb
        .{ "otherwise", TokenInfo{ .kind = .Otherwise, .flag = LexicalCategory.getFlag(.Adverb) | LexicalCategory.getFlag(.CoordinatingConjunction) } },
        // explanation : TokenKind.Explanation, LexicalCategory.Noun
        .{ "explanation", TokenInfo{ .kind = .Explanation, .flag = LexicalCategory.getFlag(.Noun) } },
        // and : TokenKind.And, LexicalCategory.CoordinatingConjunction
        .{ "and", TokenInfo{ .kind = .And, .flag = LexicalCategory.getFlag(.CoordinatingConjunction) } },
        // or : TokenKind.Or, LexicalCategory.CoordinatingConjunction
        .{ "or", TokenInfo{ .kind = .Or, .flag = LexicalCategory.getFlag(.CoordinatingConjunction) } },

        .{ "following", TokenInfo{ .kind = .Following, .flag = LexicalCategory.getFlag(.Noun) } },

        // 5W1H疑問詞
        // .{ "what", TokenInfo{ .kind = .What, .flag = LexicalCategory.getFlag(.WhWord) } },
        // .{ "when", TokenInfo{ .kind = .When, .flag = LexicalCategory.getFlag(.WhWord) } },
        // .{ "where", TokenInfo{ .kind = .Where, .flag = LexicalCategory.getFlag(.WhWord) } },
        // .{ "who", TokenInfo{ .kind = .Who, .flag = LexicalCategory.getFlag(.WhWord) } },
        // .{ "why", TokenInfo{ .kind = .Why, .flag = LexicalCategory.getFlag(.WhWord) } },
        // .{ "how", TokenInfo{ .kind = .How, .flag = LexicalCategory.getFlag(.WhWord) } },
        // .{ "which", TokenInfo{ .kind = .Which, .flag = LexicalCategory.getFlag(.WhWord) } },
        // .{ "whose", TokenInfo{ .kind = .Whose, .flag = LexicalCategory.getFlag(.WhWord) } },
        // .{ "whom", TokenInfo{ .kind = .Whom, .flag = LexicalCategory.getFlag(.WhWord) } },

        // 比較級形容詞・副詞
        // .{ "bigger", TokenInfo{ .kind = .Bigger, .flag = LexicalCategory.getFlag(.Adjective) } },
        // .{ "smaller", TokenInfo{ .kind = .Smaller, .flag = LexicalCategory.getFlag(.Adjective) } },
        // .{ "older", TokenInfo{ .kind = .Older, .flag = LexicalCategory.getFlag(.Adjective) } },
        // .{ "younger", TokenInfo{ .kind = .Younger, .flag = LexicalCategory.getFlag(.Adjective) } },
        // .{ "taller", TokenInfo{ .kind = .Taller, .flag = LexicalCategory.getFlag(.Adjective) } },
        // .{ "shorter", TokenInfo{ .kind = .Shorter, .flag = LexicalCategory.getFlag(.Adjective) } },
        // .{ "faster", TokenInfo{ .kind = .Faster, .flag = LexicalCategory.getFlag(.Adjective) } },
        // .{ "slower", TokenInfo{ .kind = .Slower, .flag = LexicalCategory.getFlag(.Adjective) } },
        // .{ "better", TokenInfo{ .kind = .Better, .flag = LexicalCategory.getFlag(.Adjective) } },
        // .{ "worse", TokenInfo{ .kind = .Worse, .flag = LexicalCategory.getFlag(.Adjective) } },
        .{ "more", TokenInfo{ .kind = .More, .flag = LexicalCategory.getFlag(.Adverb) } },
        .{ "most", TokenInfo{ .kind = .Most, .flag = LexicalCategory.getFlag(.Adverb) } },
        // .{ "less", TokenInfo{ .kind = .Less, .flag = LexicalCategory.getFlag(.Adverb) } },
        .{ "bigger", TokenInfo{ .kind = .Bigger, .flag = LexicalCategory.getFlag(.Adjective) | LexicalCategory.getFlag(.Comparative) } },
        .{ "smaller", TokenInfo{ .kind = .Smaller, .flag = LexicalCategory.getFlag(.Adjective) | LexicalCategory.getFlag(.Comparative) } },
        .{ "biggest", TokenInfo{ .kind = .Biggest, .flag = LexicalCategory.getFlag(.Adjective) | LexicalCategory.getFlag(.Superlative) } },
        .{ "smallest", TokenInfo{ .kind = .Smallest, .flag = LexicalCategory.getFlag(.Adjective) | LexicalCategory.getFlag(.Superlative) } },
        .{ "big", TokenInfo{ .kind = .Big, .flag = LexicalCategory.getFlag(.Adjective) | LexicalCategory.getFlag(.ComparableAdjective) } },
        .{ "small", TokenInfo{ .kind = .Small, .flag = LexicalCategory.getFlag(.Adjective) | LexicalCategory.getFlag(.ComparableAdjective) } },
        .{ "than", TokenInfo{ .kind = .Than, .flag = LexicalCategory.getFlag(.Preposition) } },

        // 特殊な形容詞
        .{ "sv", TokenInfo{ .kind = .SV, .flag = LexicalCategory.getFlag(.Adjective) } },
        .{ "svo", TokenInfo{ .kind = .SVO, .flag = LexicalCategory.getFlag(.Adjective) } },
        .{ "svc", TokenInfo{ .kind = .SVC, .flag = LexicalCategory.getFlag(.Adjective) } },
        .{ "svoc", TokenInfo{ .kind = .SVOC, .flag = LexicalCategory.getFlag(.Adjective) } },
        .{ "svoo", TokenInfo{ .kind = .SVOO, .flag = LexicalCategory.getFlag(.Adjective) } },

        // Number
        .{ "zero", TokenInfo{ .kind = .IntegerLiteral, .flag = LexicalCategory.getFlag(.Noun) } },

        // 否定・その他
        .{ "not", TokenInfo{ .kind = .Not, .flag = LexicalCategory.getFlag(.Adverb) | LexicalCategory.getFlag(.Negation) } },
        .{ "no", TokenInfo{ .kind = .No, .flag = LexicalCategory.getFlag(.Adjective) | LexicalCategory.getFlag(.Noun) | LexicalCategory.getFlag(.Negation) } },
        // .{ "else", TokenInfo{ .kind = .Else, .flag = LexicalCategory.getFlag(.Adverb) } },

        // // 指示代名詞
        // .{ "those", TokenInfo{ .kind = .Those, .flag = LexicalCategory.getFlag(.Determiner) | LexicalCategory.getFlag(.Pronoun) } },
    });

    pub fn get_keyword(original: []const u8) ?TokenInfo {
        return keywords.get(original);
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
        var tokenizer = Tokenizer{ .buffer = buffer, .index = 0, .start = 0, .line_offset = 0, .line = 1, .pos = undefined };
        eat_whitespace(&tokenizer);
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
        self.pos = self.get_pos();
        defer self.eat_whitespace();
        return self.lexNormal();
    }

    pub inline fn get_lower(original: []const u8) []const u8 {
        if (original.len == 0) return original;
        const allocator = std.heap.page_allocator;
        const lower = allocator.alloc(u8, original.len) catch return original;
        @memcpy(lower[1..], original[1..]);
        lower[0] = std.ascii.toLower(original[0]);
        return lower;
    }

    pub fn lexNormal(self: *Tokenizer) Token {
        switch (self.buffer[self.index]) {
            0 => {
                if (self.index == self.buffer.len) {
                    return .{
                        .kind = .EOF,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                        .pos = self.pos,
                    };
                } else {
                    return .{
                        .kind = .Error,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                        .pos = self.pos,
                    };
                }
            },
            'a'...'z', 'A'...'Z' => {
                self.index += 1;
                return self.lexIdentifier();
            },
            '/' => {
                self.index += 1;
                if (self.buffer[self.index] == '/') {
                    // slashでのコメントは使えないというエラーを返す
                    // 行の終わりまで読み飛ばす
                    while (self.buffer[self.index] != 0 and self.buffer[self.index] != '\n') {
                        self.index += 1;
                    }
                    return .{
                        .kind = .DOUBLE_SLASH_COMMENT_ERROR,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                        .pos = self.pos,
                    };
                }
                if (self.buffer[self.index] == '*') {
                    // /* でのコメントは使えないというエラーを返す
                    // */ まで読み飛ばす
                    while (self.buffer[self.index] != 0) {
                        if (self.buffer[self.index] == '*' and self.buffer[self.index + 1] == '/') break;
                        if (self.buffer[self.index] == '\n') self.next_line();
                        self.index += 1;
                    }
                    // `*/` の２文字を消費
                    if (self.buffer[self.index] == '*') self.index += 2;
                    return .{
                        .kind = .SLASH_ASTERISK_COMMENT_ERROR,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                        .pos = self.pos,
                    };
                } else {
                    return .{
                        .kind = .Divide,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Operator),
                        .pos = self.pos,
                    };
                }
            },
            '#' => {
                // # でのコメントは使えないというエラーを返す
                // 行の終わりまで読み飛ばす
                while (self.buffer[self.index] != 0 and self.buffer[self.index] != '\n') {
                    self.index += 1;
                }
                return .{
                    .kind = .HASH_COMMENT_ERROR,
                    .loc = .{
                        .start = self.start,
                        .end = self.index,
                    },
                    .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                    .pos = self.pos,
                };
            },
            '*' => {
                self.index += 1;
                if (self.buffer[self.index] == '/') {
                    // */ でのコメントは使えないというエラーを返す
                    // 単体の場合はこのTokenのみ読み飛ばす
                    self.index += 1;
                    return .{
                        .kind = .ASTERISK_SLASH_COMMENT_ERROR,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                        .pos = self.pos,
                    };
                } else {
                    return .{
                        .kind = .Multiply,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Operator),
                        .pos = self.pos,
                    };
                }
            },
            ':' => {
                self.index += 1;
                if (self.buffer[self.index] == '=') {
                    // := での代入は使えないというエラーを返す
                    // 次の.or;or\nまで読み飛ばす
                    while (self.buffer[self.index] != 0 and self.buffer[self.index] != '\n' and self.buffer[self.index] != ';' and self.buffer[self.index] != '.') {
                        self.index += 1;
                    }
                    return .{
                        .kind = .COLON_EQUAL_ASSIGNMENT_ERROR,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                        .pos = self.pos,
                    };
                } else if (self.buffer[self.index] == ':') {
                    // :: での代入や参照は使えないというエラーを返す
                    // 次の.or;or\nまで読み飛ばす
                    while (self.buffer[self.index] != 0 and self.buffer[self.index] != '\n' and self.buffer[self.index] != ';' and self.buffer[self.index] != '.') {
                        self.index += 1;
                    }
                    return .{
                        .kind = .COLON_COLON_OPERATOR_ERROR,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                        .pos = self.pos,
                    };
                } else {
                    return .{
                        .kind = .Colon,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Punctuation),
                        .pos = self.pos,
                    };
                }
            },
            '.' => {
                self.index += 1;
                if (self.buffer[self.index] == '.') {
                    // .. での代入や参照は使えないというエラーを返す
                    // 次の.or;or\nまで読み飛ばす
                    while (self.buffer[self.index] != 0 and self.buffer[self.index] != '\n' and self.buffer[self.index] != ';' and self.buffer[self.index] != '.') {
                        self.index += 1;
                    }
                    return .{
                        .kind = .DOT_DOT_OPERATOR_ERROR,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                        .pos = self.pos,
                    };
                } else {
                    return .{
                        .kind = .Period,
                        .loc = .{
                            .start = self.start,
                            .end = self.index,
                        },
                        .lexical_flag = Token.LexicalCategory.getFlag(.Punctuation),
                        .pos = self.pos,
                    };
                }
            },
            ',' => {
                self.index += 1;
                return .{
                    .kind = .Comma,
                    .loc = .{
                        .start = self.start,
                        .end = self.index,
                    },
                    .lexical_flag = Token.LexicalCategory.getFlag(.Punctuation),
                    .pos = self.pos,
                };
            },
            ';' => {
                self.index += 1;
                return .{
                    .kind = .Semicolon,
                    .loc = .{
                        .start = self.start,
                        .end = self.index,
                    },
                    .lexical_flag = Token.LexicalCategory.getFlag(.Punctuation),
                    .pos = self.pos,
                };
            },
            '?' => {
                self.index += 1;
                return .{
                    .kind = .QuestionMark,
                    .loc = .{
                        .start = self.start,
                        .end = self.index,
                    },
                    .lexical_flag = Token.LexicalCategory.getFlag(.Punctuation),
                    .pos = self.pos,
                };
            },
            '$' => {
                self.index += 1;
                // $なんて使えないよというエラーを返す
                // とりあえずこのTokenを読み飛ばす
                return .{
                    .kind = .DOLLAR_SIGN_OPERATOR_ERROR,
                    .loc = .{
                        .start = self.start,
                        .end = self.index,
                    },
                    .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                    .pos = self.pos,
                };
            },
            '"' => {
                return self.lexString();
            },
            '0' => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '0'...'9' => {
                        // 0なら大丈夫だが01などはエラー
                        return .{
                            .kind = .INTEGER_LITERAL_ERROR,
                            .loc = .{
                                .start = self.start,
                                .end = self.index,
                            },
                            .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                            .pos = self.pos,
                        };
                    },
                    '.' => return self.lexFloat(),
                    else => {
                        return .{
                            .kind = .IntegerLiteral,
                            .loc = .{
                                .start = self.start,
                                .end = self.index,
                            },
                            .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                            .pos = self.pos,
                        };
                    },
                }
            },
            '1'...'9' => {
                return self.lexNumber();
            },
            '+' => {
                self.index += 1;
                return .{
                    .kind = .Plus,
                    .loc = .{
                        .start = self.start,
                        .end = self.index,
                    },
                    .lexical_flag = Token.LexicalCategory.getFlag(.Operator),
                    .pos = self.pos,
                };
            },
            '-' => {
                self.index += 1;
                return .{
                    .kind = .Minus,
                    .loc = .{
                        .start = self.start,
                        .end = self.index,
                    },
                    .lexical_flag = Token.LexicalCategory.getFlag(.Operator),
                    .pos = self.pos,
                };
            },
            else => {
                self.index += 1;
                return .{
                    .kind = .Error,
                    .loc = .{
                        .start = self.start,
                        .end = self.index,
                    },
                    .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                    .pos = self.pos,
                };
            },
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
        const lower = Tokenizer.get_lower(self.buffer[self.start..self.index]);
        if (lower.len == 4 and std.mem.eql(u8, lower, "note") and self.buffer[self.index] == ':') {
            // コメントを返す
            // 末尾チェック付きで行末までジャンプ
            while (self.buffer[self.index] != 0 and self.buffer[self.index] != '\n') {
                self.index += 1;
            }
            return .{
                .kind = .COMMENT,
                .loc = .{
                    .start = self.start,
                    .end = self.index,
                },
                .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                .pos = self.pos,
            };
        }
        defer std.heap.page_allocator.free(lower);

        const keyword = Token.get_keyword(lower);
        const is_upper = std.ascii.isUpper(self.buffer[self.start]);
        if (keyword) |k| {
            return .{
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
        return Token{
            .kind = .Identifier,
            .lexical_flag = Token.LexicalCategory.getFlag(.Noun),
            .loc = .{
                .start = self.start,
                .end = self.index,
            },
            .contentsHash = Fnv1a_64.hash(self.buffer[self.start..self.index]),
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
                .kind = .STRING_CLOSE_ERROR,
                .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                .loc = .{
                    .start = self.start,
                    .end = self.index,
                },
                .pos = self.pos,
            };
        } else {
            self.index += 1;
            return .{
                .kind = .StringLiteral,
                .lexical_flag = Token.LexicalCategory.getFlag(.Noun),
                .loc = .{
                    .start = self.start,
                    .end = self.index,
                },
                .pos = self.pos,
            };
        }
    }

    pub fn lexNumber(self: *Tokenizer) Token {
        while (true) {
            switch (self.buffer[self.index]) {
                '0'...'9' => self.index += 1,
                '.' => return self.lexFloat(),
                else => break,
            }
        }
        return .{
            .kind = .IntegerLiteral,
            .lexical_flag = Token.LexicalCategory.getFlag(.Noun),
            .loc = .{
                .start = self.start,
                .end = self.index,
            },
            .pos = self.pos,
        };
    }

    pub fn lexFloat(self: *Tokenizer) Token {
        self.index += 1;
        const c = self.buffer[self.index];
        if (!std.ascii.isDigit(c)) {
            return .{
                .kind = .FLOAT_LITERAL_ERROR,
                .lexical_flag = Token.LexicalCategory.getFlag(.Unknown),
                .loc = .{
                    .start = self.start,
                    .end = self.index,
                },
                .pos = self.pos,
            };
        }
        while (true) {
            switch (self.buffer[self.index]) {
                '0'...'9' => self.index += 1,
                else => break,
            }
        }
        return .{
            .kind = .FloatLiteral,
            .lexical_flag = Token.LexicalCategory.getFlag(.Noun),
            .loc = .{
                .start = self.start,
                .end = self.index,
            },
            .pos = self.pos,
        };
    }
};

test "get_keyword" {
    const lowerT = Tokenizer.get_lower("That");
    const defaultLowerT = Tokenizer.get_lower("that");
    const t = Token.get_keyword(lowerT);
    const T = Token.get_keyword(defaultLowerT);
    try std.testing.expect(t.?.kind == Token.TokenKind.That);
    try std.testing.expect(T.?.kind == Token.TokenKind.That);
}

test "LexicalCategory" {
    const t = Token.get_keyword("that");
    try std.testing.expect(t.?.kind == Token.TokenKind.That);
    try std.testing.expect(t.?.flag == Token.LexicalCategory.getFlag(.Pronoun));
}

test "LexicalCategoryByFlag" {
    const t = Token.get_keyword("that") orelse return error.TestFailure;
    const allocator = std.testing.allocator;
    const kinds = try Token.LexicalCategory.flagToArray(t.flag, allocator);
    defer kinds.deinit();

    try std.testing.expect(kinds.items.len == 1);
    try std.testing.expect(kinds.items[0] == Token.LexicalCategory.Pronoun);
}

test "LexicalCategoryCheckFlag" {
    const t = Token.get_keyword("that");
    try std.testing.expect(t.?.kind == Token.TokenKind.That);
    try std.testing.expect(t.?.flag ==
        Token.LexicalCategory.getFlag(.Pronoun));
    try std.testing.expect(Token.LexicalCategory.checkFlag(t.?.flag, Token.LexicalCategory.Pronoun));
    try std.testing.expect(!Token.LexicalCategory.checkFlag(t.?.flag, Token.LexicalCategory.Verb));
}

test "Tokenizer1" {
    const buffer: [:0]const u8 = "let b be 3";

    var tokenizer = Tokenizer.init(buffer);
    const tokenLet = tokenizer.next();
    try std.testing.expect(tokenLet.kind == Token.TokenKind.Let);
    try std.testing.expect(tokenLet.lexical_flag == Token.LexicalCategory.getFlag(.Verb) | Token.LexicalCategory.getFlag(.LetVerb));
    try std.testing.expect(tokenLet.loc.start == 0);
    try std.testing.expect(tokenLet.loc.end == 3);
    const tokenA = tokenizer.next();
    try std.testing.expect(tokenA.kind == Token.TokenKind.Identifier);
    try std.testing.expect(tokenA.lexical_flag == Token.LexicalCategory.getFlag(.Noun));
    try std.testing.expect(tokenA.loc.start == 4);
    try std.testing.expect(tokenA.loc.end == 5);
    const tokenBe = tokenizer.next();
    try std.testing.expect(tokenBe.kind == Token.TokenKind.Be);
    try std.testing.expect(tokenBe.lexical_flag == Token.LexicalCategory.getFlag(.Copula) | Token.LexicalCategory.getFlag(.SVCVerb) | Token.LexicalCategory.getFlag(.Verb));
    try std.testing.expect(tokenBe.loc.start == 6);
    try std.testing.expect(tokenBe.loc.end == 8);
    const token3 = tokenizer.next();
    try std.testing.expect(token3.kind == Token.TokenKind.IntegerLiteral);
    try std.testing.expect(token3.lexical_flag == Token.LexicalCategory.getFlag(.Noun));
    try std.testing.expect(token3.loc.start == 9);
    try std.testing.expect(token3.loc.end == 10);
    const tokenEOF = tokenizer.next();
    try std.testing.expect(tokenEOF.kind == Token.TokenKind.EOF);
    try std.testing.expect(tokenEOF.lexical_flag == Token.LexicalCategory.getFlag(.Unknown));
    try std.testing.expect(tokenEOF.loc.start == 10);
    try std.testing.expect(tokenEOF.loc.end == 10);
    try std.testing.expect(tokenEOF.pos.line == 1);
    try std.testing.expect(tokenEOF.pos.column == 11);
    try std.testing.expect(tokenEOF.pos.line_offset == 0);
}

test "TokenizerNextLine" {
    const buffer: [:0]const u8 = "let a be 3\nlet b be 4";

    var tokenizer = Tokenizer.init(buffer);
    const tokenLet = tokenizer.next();
    try std.testing.expect(tokenLet.kind == Token.TokenKind.Let);
    try std.testing.expect(tokenLet.pos.line == 1);
    try std.testing.expect(tokenLet.pos.column == 1);
    try std.testing.expect(tokenLet.pos.line_offset == 0);

    const tokenA = tokenizer.next();
    try std.testing.expect(tokenA.kind == Token.TokenKind.A);
    try std.testing.expect(tokenA.pos.line == 1);
    try std.testing.expect(tokenA.pos.column == 5);
    try std.testing.expect(tokenA.pos.line_offset == 0);

    const tokenBe = tokenizer.next();
    try std.testing.expect(tokenBe.kind == Token.TokenKind.Be);
    try std.testing.expect(tokenBe.pos.line == 1);
    try std.testing.expect(tokenBe.pos.column == 7);
    try std.testing.expect(tokenBe.pos.line_offset == 0);

    const token3 = tokenizer.next();
    try std.testing.expect(token3.kind == Token.TokenKind.IntegerLiteral);
    try std.testing.expect(token3.pos.line == 1);
    try std.testing.expect(token3.pos.column == 10);
    try std.testing.expect(token3.pos.line_offset == 0);

    const tokenLet2 = tokenizer.next();
    try std.testing.expect(tokenLet2.kind == Token.TokenKind.Let);
    try std.testing.expect(tokenLet2.pos.line == 2);
    try std.testing.expect(tokenLet2.pos.column == 1);
    try std.testing.expect(tokenLet2.pos.line_offset == 11);

    // ポジションの確認
    try std.testing.expect(tokenLet2.loc.start == 11);
    try std.testing.expect(tokenLet2.loc.end == 14);

    try std.testing.expect(tokenizer.line == 2);
    try std.testing.expect(tokenizer.line_offset == 11);
    try std.testing.expect(tokenizer.index == 15);

    const tokenB = tokenizer.next();
    try std.testing.expect(tokenB.kind == Token.TokenKind.Identifier);
    try std.testing.expect(tokenB.pos.line == 2);
    try std.testing.expect(tokenB.pos.column == 5);

    const tokenBe2 = tokenizer.next();
    try std.testing.expect(tokenBe2.kind == Token.TokenKind.Be);
    try std.testing.expect(tokenBe2.pos.line == 2);
    try std.testing.expect(tokenBe2.pos.column == 7);

    const token4 = tokenizer.next();
    try std.testing.expect(token4.kind == Token.TokenKind.IntegerLiteral);
    try std.testing.expect(token4.pos.line == 2);
    try std.testing.expect(token4.pos.column == 10);

    const tokenEOF = tokenizer.next();
    try std.testing.expect(tokenEOF.kind == Token.TokenKind.EOF);
}

test "Slash-asterisk comment (single-line)" {
    const buffer: [:0]const u8 = "/* this is a comment */";
    var tokenizer = Tokenizer.init(buffer);
    const token = tokenizer.next();
    try std.testing.expect(token.kind == .SLASH_ASTERISK_COMMENT_ERROR);
    try std.testing.expect(token.loc.start == 0);
    // コメント末尾の '/' までを消費していることを確認
    try std.testing.expect(token.loc.end == buffer.len);
}

test "Slash-asterisk comment unterminated" {
    const buffer: [:0]const u8 = "/* unterminated comment";
    var tokenizer = Tokenizer.init(buffer);
    const token = tokenizer.next();
    try std.testing.expect(token.kind == .SLASH_ASTERISK_COMMENT_ERROR);
    try std.testing.expect(token.loc.start == 0);
    // EOFまで走査していることを確認
    try std.testing.expect(token.loc.end == buffer.len);
}

test "Note comment lowercase" {
    const buffer: [:0]const u8 = "note: this is a note comment";
    var tokenizer = Tokenizer.init(buffer);
    const token = tokenizer.next();
    try std.testing.expect(token.kind == .COMMENT);
    try std.testing.expect(token.loc.start == 0);
    // バッファ末尾まで消費されていること
    try std.testing.expect(token.loc.end == buffer.len);
}

test "Note comment uppercase initial" {
    const buffer: [:0]const u8 = "Note: Another comment here";
    var tokenizer = Tokenizer.init(buffer);
    const token = tokenizer.next();
    std.debug.assert(token.kind == .COMMENT);
    std.debug.assert(token.loc.start == 0);
    std.debug.assert(token.loc.end == buffer.len);
}

test "contents hash test" {
    const buffer: [:0]const u8 = "sample sample nonSample";
    var tokenizer = Tokenizer.init(buffer);
    const sample1 = tokenizer.next();
    const sample2 = tokenizer.next();
    const non_sample = tokenizer.next();
    try std.testing.expect(sample1.contentsHash == sample2.contentsHash);
    try std.testing.expect(sample1.contentsHash != non_sample.contentsHash);
}

test "flag memory test" {
    const allocator = std.testing.allocator;
    const lexical_flag =
        Token.LexicalCategory.getFlag(.Pronoun);
    const lexical_flag_array = try Token.LexicalCategory.flagToArray(lexical_flag, allocator);
    for (lexical_flag_array.items) |flag| {
        std.debug.print("flag: {any}\n", .{flag});
    }
    try std.testing.expect(lexical_flag_array.items[0] == Token.LexicalCategory.Pronoun);
    try std.testing.expect(lexical_flag_array.items.len == 1);
    defer lexical_flag_array.deinit();
}

test "keyword test" {
    const keywords = Token.keywords;
    const keys = keywords.keys();
    try std.testing.expect(keys.len > 0);
    for (keys) |key| {
        const end_with_0_key: [:0]const u8 = key.ptr[0..key.len :0];
        var tokenizer = Tokenizer.init(end_with_0_key);
        const token = tokenizer.next();
        const token_info = keywords.get(key) orelse {
            std.debug.print("Keyword not found: {s}\n", .{key});
            return error.TestFailure;
        };
        try std.testing.expect(token.kind == token_info.kind);
        try std.testing.expect(token.lexical_flag == token_info.flag);
    }
}
