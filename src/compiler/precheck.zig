const tokenizer = @import("tokenizer.zig");
const ast = @import("ast.zig");
const std = @import("std");
const Token = tokenizer.Token;
const LexicalCategory = Token.LexicalCategory;
const TokenAndStateList = ast.TokenAndStateList;
const ThreeFlag = ast.ThreeFlag;
const Error = ast.Error;
const parser = @import("parser.zig");

pub const PreCheck = struct {
    tokens: TokenAndStateList,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, tokens: TokenAndStateList) PreCheck {
        return PreCheck{
            .tokens = tokens,
            .allocator = allocator,
        };
    }

    /// 定義（Define）トークンを収集し、Checked状態にマークする
    pub fn crawlDefine(self: *PreCheck) !void {
        var defineIndexes = try self.findDefines();
        defer defineIndexes.deinit();

        for (defineIndexes.items) |idx| {
            self.smallParseDefine(idx);
        }
    }

    /// Define ヘッダ部を簡易解析して、解析成功時に全てにCheckedフラグを立てる
    pub fn smallParseDefine(self: *PreCheck, defineIndex: usize) void {
        // "I define a ..." 構造をチェック
        const startIndex = defineIndex - 1;
        // 残りがendIndexを返すので, startIndex,endIndexをsetCategorySameIdentifierに渡す
        // 先頭に "I" が 1 つだけ必要なので define は 1 以上でなければならない
        if (defineIndex == 0) return;
        if (self.tokens.items(.kind)[defineIndex - 1] != Token.TokenKind.I) return;
        const artKind = self.tokens.items(.kind)[defineIndex + 1];
        if (artKind != Token.TokenKind.A and artKind != Token.TokenKind.An) return;

        // 次のトークン種別で振り分け
        const nextKind = self.tokens.items(.kind)[defineIndex + 2];
        var endIndex: ?usize = undefined;
        if (nextKind == Token.TokenKind.Function) {
            endIndex = self.smallParseFunction(defineIndex + 2);
        } else if (nextKind == Token.TokenKind.SV or
            nextKind == Token.TokenKind.SVO or
            nextKind == Token.TokenKind.SVC or
            nextKind == Token.TokenKind.SVOC or
            nextKind == Token.TokenKind.SVOO)
        {
            endIndex = self.smallParseVerb(defineIndex + 2);
        }
        // else if (nextKind == Token.TokenKind.Entity) {
        //     endIndex = self.smallParseEntity(defineIndex + 2);
        // }
        if (endIndex) |end| {
            self.setCheckedFlag(startIndex, end);
        } else {
            return;
        }
    }

    /// "I define a function ..." 部分を解析してsetCategorySameIdentifierを呼ぶ、成功時に終了位置を返す
    pub fn smallParseFunction(self: *PreCheck, idx: usize) ?usize {
        const len = self.tokens.len;
        // idx は Function トークン位置
        // Called
        if (idx + 1 >= len or self.tokens.items(.kind)[idx + 1] != Token.TokenKind.Called) return null;

        // 関数名
        if (idx + 2 >= len or self.tokens.items(.kind)[idx + 2] != Token.TokenKind.Identifier) return null;

        if (idx + 3 >= len or self.tokens.items(.kind)[idx + 3] != Token.TokenKind.Period) return null;

        return idx + 4;
    }

    fn expectTokens(self: *PreCheck, startIdx: usize, expectedTokens: []const Token.TokenKind) ?usize {
        for (expectedTokens, 0..) |expected, offset| {
            const idx = startIdx + offset;
            if (idx >= self.tokens.len or self.tokens.items(.kind)[idx] != expected) {
                return null;
            }
        }
        return startIdx + expectedTokens.len;
    }

    /// "I define a sv... verb ..." 部分を解析してsetCategorySameIdentifierを呼ぶ、成功時に終了位置を返す
    pub fn smallParseVerb(self: *PreCheck, idx: usize) ?usize {
        // svoc部分が渡される
        switch (self.tokens.items(.kind)[idx]) {
            Token.TokenKind.SV, Token.TokenKind.SVO, Token.TokenKind.SVC, Token.TokenKind.SVOC, Token.TokenKind.SVOO => {
                const pattern = [_]Token.TokenKind{ .Verb, .Called, .Identifier, .Period };
                const endIdx = self.expectTokens(idx + 1, &pattern) orelse return null;
                if (self.tokens.items(.kind)[idx] == Token.TokenKind.SV) {
                    self.setCategorySameIdentifier(LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVVerb), idx + 3);
                } else if (self.tokens.items(.kind)[idx] == Token.TokenKind.SVO) {
                    self.setCategorySameIdentifier(LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOVerb), idx + 3);
                } else if (self.tokens.items(.kind)[idx] == Token.TokenKind.SVC) {
                    self.setCategorySameIdentifier(LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVCVerb), idx + 3);
                } else if (self.tokens.items(.kind)[idx] == Token.TokenKind.SVOC) {
                    self.setCategorySameIdentifier(LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOCVerb), idx + 3);
                } else if (self.tokens.items(.kind)[idx] == Token.TokenKind.SVOO) {
                    self.setCategorySameIdentifier(LexicalCategory.getFlag(.Verb) | LexicalCategory.getFlag(.SVOOVerb), idx + 3);
                }
                return endIdx;
            },
            else => return null,
        }
    }

    // /// defineの後に続くtokenがentityだった時にトークンを解析する 現在は何もサポートしない
    // pub fn smallParseEntity(self: *PreCheck, entityIndex: usize) ?usize {
    //     _ = self;
    //     _ = entityIndex;
    //     std.debug.print("Entity is not supported yet\n", .{});
    //     return null;
    // }

    /// 全Defineトークンの位置をリストで返す
    pub fn findDefines(self: *PreCheck) !std.ArrayList(usize) {
        var defines = std.ArrayList(usize).init(self.allocator);
        var i: usize = 0;
        while (i < self.tokens.len) : (i += 1) {
            if (self.tokens.items(.kind)[i] == Token.TokenKind.Define and self.tokens.items(.state)[i] != ThreeFlag.getFlag(.Checked)) {
                try defines.append(i);
            }
        }
        return defines;
    }

    /// Tokenを startIndex から endIndex まで (両端を含む) Checked にする 初めのtokenにはPCheckedもCheckedも付与する
    pub fn setCheckedFlag(self: *PreCheck, startIndex: usize, endIndex: usize) void {
        if (startIndex >= self.tokens.len) return;
        const last: usize = @min(endIndex, self.tokens.len);

        var i: usize = startIndex + 1;
        self.tokens.items(.state)[startIndex] = ThreeFlag.getFlag(.PChecked) | ThreeFlag.getFlag(.Checked);
        while (i < last) : (i += 1) {
            self.tokens.items(.state)[i] = ThreeFlag.getFlag(.Checked);
        }
    }

    /// あるIndexのトークンと同じ種類のTokenすべてのLexicalCategoryのフラグを設定する (将来的に一つの動詞に複数の使い方をさせることも考えてこうしている)
    pub fn setCategorySameIdentifier(self: *PreCheck, category: u64, index: usize) void {
        const tokenHash: ?u64 = self.tokens.items(.contentsHash)[index];
        if (tokenHash == null) {
            return;
        }
        for (self.tokens.items(.contentsHash), 0..) |hash, i| {
            if (hash == tokenHash and i != index) {
                self.tokens.items(.category)[i] |= category;
                self.tokens.items(.category)[i] &= ((comptime ~Token.LexicalCategory.getFlag(.Noun)) | category);
            }
        }
        // self.tokens.items(.category)[index] = Token.LexicalCategory.getFlag(.Noun);
    }
};

test "PreCheck function" {
    const buffer: [:0]const u8 = "I define a function called sampleSomething. sampleSomething";
    const allocator = std.testing.allocator;
    var tokenList = ast.getTokenList(allocator, buffer) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer tokenList.deinit(allocator);

    try std.testing.expect(tokenList.items(.category)[tokenList.len - 1] == LexicalCategory.getFlag(.Noun));

    //std.debug.print("Token List Items: {any}\n", .{Token.LexicalCategory.flagToArray(tokenList.items(.category)[tokenList.len - 1])});
    var preCheck = PreCheck.init(std.testing.allocator, tokenList);
    try preCheck.crawlDefine();
    for (1..tokenList.len - 1) |i| {
        try std.testing.expect(tokenList.items(.state)[i] == ThreeFlag.getFlag(.Checked));
    }
    try std.testing.expect(tokenList.items(.state)[0] == ThreeFlag.getFlag(.PChecked) | ThreeFlag.getFlag(.Checked));
    try std.testing.expect(tokenList.items(.category)[5] == LexicalCategory.getFlag(.Noun));
    try std.testing.expect(tokenList.items(.state)[tokenList.len - 1] == ThreeFlag.getFlag(.Unprocessed));
    try std.testing.expect(tokenList.items(.category)[tokenList.len - 1] == LexicalCategory.getFlag(.Noun));
}

test "PreCheck sv verb" {
    const buffer: [:0]const u8 = "I define a sv verb called sampleSomething. sampleSomething";
    const allocator = std.testing.allocator;
    var tokenList = ast.getTokenList(allocator, buffer) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer tokenList.deinit(allocator);
    try std.testing.expect(tokenList.items(.category)[tokenList.len - 1] == LexicalCategory.getFlag(.Noun));

    var preCheck = PreCheck.init(std.testing.allocator, tokenList);
    try preCheck.crawlDefine();
    for (1..tokenList.len - 1) |i| {
        try std.testing.expect(tokenList.items(.state)[i] == ThreeFlag.getFlag(.Checked));
    }
    try std.testing.expect(tokenList.items(.state)[0] == ThreeFlag.getFlag(.PChecked) | ThreeFlag.getFlag(.Checked));

    try std.testing.expect(tokenList.items(.category)[6] == LexicalCategory.getFlag(.Noun));
    try std.testing.expect(tokenList.items(.state)[tokenList.len - 1] == ThreeFlag.getFlag(.Unprocessed));
    try std.testing.expectEqual((LexicalCategory.getFlag(.SVVerb) | LexicalCategory.getFlag(.Verb)), tokenList.items(.category)[tokenList.len - 1]);
}

test "PreCheck svo verb" {
    const buffer: [:0]const u8 = "I define a svo verb called sampleSomething. sampleSomething";
    const allocator = std.testing.allocator;
    var tokenList = ast.getTokenList(allocator, buffer) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer tokenList.deinit(allocator);
    try std.testing.expect(tokenList.items(.category)[tokenList.len - 1] == LexicalCategory.getFlag(.Noun));

    var preCheck = PreCheck.init(std.testing.allocator, tokenList);
    try preCheck.crawlDefine();
    for (1..tokenList.len - 1) |i| {
        try std.testing.expect(tokenList.items(.state)[i] == ThreeFlag.getFlag(.Checked));
    }
    try std.testing.expect(tokenList.items(.state)[0] == ThreeFlag.getFlag(.PChecked) | ThreeFlag.getFlag(.Checked));
    try std.testing.expect(tokenList.items(.category)[6] == LexicalCategory.getFlag(.Noun));
    try std.testing.expect(tokenList.items(.state)[tokenList.len - 1] == ThreeFlag.getFlag(.Unprocessed));
    try std.testing.expectEqual((LexicalCategory.getFlag(.SVOVerb) | LexicalCategory.getFlag(.Verb)), tokenList.items(.category)[tokenList.len - 1]);
}

test "PreCheck svc verb" {
    const buffer: [:0]const u8 = "I define a svc verb called sampleSomething. sampleSomething";
    const allocator = std.testing.allocator;
    var tokenList = ast.getTokenList(allocator, buffer) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer tokenList.deinit(allocator);
    try std.testing.expect(tokenList.items(.category)[tokenList.len - 1] == LexicalCategory.getFlag(.Noun));

    var preCheck = PreCheck.init(std.testing.allocator, tokenList);
    try preCheck.crawlDefine();
    for (1..tokenList.len - 1) |i| {
        try std.testing.expect(tokenList.items(.state)[i] == ThreeFlag.getFlag(.Checked));
    }
    try std.testing.expect(tokenList.items(.state)[0] == ThreeFlag.getFlag(.PChecked) | ThreeFlag.getFlag(.Checked));
    try std.testing.expect(tokenList.items(.category)[6] == LexicalCategory.getFlag(.Noun));
    try std.testing.expect(tokenList.items(.state)[tokenList.len - 1] == ThreeFlag.getFlag(.Unprocessed));
    try std.testing.expectEqual((LexicalCategory.getFlag(.SVCVerb) | LexicalCategory.getFlag(.Verb)), tokenList.items(.category)[tokenList.len - 1]);
}

test "PreCheck svoc verb" {
    const buffer: [:0]const u8 = "I define a svoc verb called sampleSomething. sampleSomething";
    const allocator = std.testing.allocator;
    var tokenList = ast.getTokenList(allocator, buffer) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer tokenList.deinit(allocator);
    try std.testing.expect(tokenList.items(.category)[tokenList.len - 1] == LexicalCategory.getFlag(.Noun));
    var preCheck = PreCheck.init(std.testing.allocator, tokenList);
    try preCheck.crawlDefine();
    for (1..tokenList.len - 1) |i| {
        try std.testing.expect(tokenList.items(.state)[i] == ThreeFlag.getFlag(.Checked));
    }
    try std.testing.expect(tokenList.items(.state)[0] == ThreeFlag.getFlag(.PChecked) | ThreeFlag.getFlag(.Checked));
    try std.testing.expect(tokenList.items(.category)[6] == LexicalCategory.getFlag(.Noun));
    try std.testing.expect(tokenList.items(.state)[tokenList.len - 1] == ThreeFlag.getFlag(.Unprocessed));
    try std.testing.expectEqual((LexicalCategory.getFlag(.SVOCVerb) | LexicalCategory.getFlag(.Verb)), tokenList.items(.category)[tokenList.len - 1]);
}

test "PreCheck svoo verb" {
    const buffer: [:0]const u8 = "I define a svoo verb called sampleSomething. sampleSomething";
    const allocator = std.testing.allocator;
    var tokenList = ast.getTokenList(allocator, buffer) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer tokenList.deinit(allocator);
    try std.testing.expect(tokenList.items(.category)[tokenList.len - 1] == LexicalCategory.getFlag(.Noun));
    var preCheck = PreCheck.init(std.testing.allocator, tokenList);
    try preCheck.crawlDefine();
    for (1..tokenList.len - 1) |i| {
        try std.testing.expect(tokenList.items(.state)[i] == ThreeFlag.getFlag(.Checked));
    }
    try std.testing.expect(tokenList.items(.state)[0] == ThreeFlag.getFlag(.PChecked) | ThreeFlag.getFlag(.Checked));
    try std.testing.expect(tokenList.items(.category)[6] == LexicalCategory.getFlag(.Noun));
    try std.testing.expect(tokenList.items(.state)[tokenList.len - 1] == ThreeFlag.getFlag(.Unprocessed));
    //std.debug.print("Token List Items: {any}\n", .{Token.LexicalCategory.flagToArray(tokenList.items(.category)[tokenList.len - 1], allocator)});
    try std.testing.expectEqual((LexicalCategory.getFlag(.SVOOVerb) | LexicalCategory.getFlag(.Verb)), tokenList.items(.category)[tokenList.len - 1]);
}

// test "PreCheck entity" {
//     const buffer: [:0]const u8 = "I define a entity called sampleSomething. sampleSomething";
//     const allocator = std.testing.allocator;
//     var tokenList = ast.getTokenList(allocator, buffer) catch |err| {
//         std.debug.print("Error: {}\n", .{err});
//         return err;
//     };
//     defer tokenList.deinit(allocator);
//     try std.testing.expect(tokenList.items(.category)[tokenList.len - 1] == LexicalCategory.getFlag(.Noun));
//     var preCheck = PreCheck.init(std.testing.allocator, tokenList);
//     try preCheck.crawlDefine();
//     for (0..tokenList.len) |i| {
//         try std.testing.expect(tokenList.items(.state)[i] == ThreeFlag.getFlag(.Unprocessed));
//     }
//     try std.testing.expect(tokenList.items(.category)[5] == LexicalCategory.getFlag(.Noun));
//     try std.testing.expect(tokenList.items(.category)[tokenList.len - 1] == LexicalCategory.getFlag(.Noun));
// }
