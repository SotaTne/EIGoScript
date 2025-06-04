const std = @import("std");
const ast = @import("ast.zig");
const sub_parser = @import("sub_parser.zig");
const SubParser = sub_parser.SubParser;
const ParseResult = sub_parser.ParseResult;
const SubNode = sub_parser.SubNode;
const SubNodeIndex = sub_parser.SubNodeIndex;
const SubNodeTag = sub_parser.SubNodeTag;
const SubAstStructs = sub_parser.SubAstStructs;

const TestSubNodeCase = struct {
    text: [:0]const u8,
    result: ParseResult,
    expected_nodes: []const SubNode,
};

fn testSubjectSubNodes(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseSubject(0) orelse {
            std.debug.print("Failed to parse subject for input: {s}\n", .{case.text});
            return error.Failure;
        };

        try std.testing.expectEqual(case.result, result);

        // sub_nodesが期待ノードリストと同じ数か
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        // フィールドごとに一致しているか検証
        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected.startTokenIndex, actual.startTokenIndex);
        }
    }
}

test "Subject Parse" {
    const allocator = std.testing.allocator;

    // テストパターン定義
    const cases = [_]TestSubNodeCase{
        .{
            .text = "I",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = true },
                .next_token_index = 1,
                .tag = SubNodeTag.Subject,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.Subject,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = true,
                },
            },
        },
        .{
            .text = "You",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = true },
                .next_token_index = 1,
                .tag = SubNodeTag.Subject,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.Subject,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = true,
                },
            },
        },
        .{
            .text = "We",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = true },
                .next_token_index = 1,
                .tag = SubNodeTag.Subject,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.Subject,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = true,
                },
            },
        },
    };
    try testSubjectSubNodes(&cases, allocator);
}

fn testParseNegationNodes(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseNegation(0) orelse {
            std.debug.print("Failed to parse negation for input: {s}\n", .{case.text});
            return error.Failure;
        };

        try std.testing.expectEqual(case.result, result);

        // sub_nodesが期待ノードリストと同じ数か
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        // フィールドごとに一致しているか検証
        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Negation Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        .{
            .text = "not",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.NegationPhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NegationPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "no",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.NegationPhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NegationPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
    };

    try testParseNegationNodes(&cases, allocator);
}

fn testParseAdjectiveNodes(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseAdjective(0) orelse {
            std.debug.print("Failed to parse adjective for input: {s}\n", .{case.text});
            return error.Failure;
        };

        std.debug.print("Parsed result: {any}\n", .{result});
        std.debug.print("Expected result: {any}\n", .{case.result});

        try std.testing.expectEqual(case.result, result);

        std.debug.print("SubParser sub_nodes: {any}\n", .{subParser.sub_nodes});

        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Adjective Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        .{
            .text = "more big",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 2, .isRoot = false },
                .next_token_index = 2,
                .tag = SubNodeTag.AdjectivePhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.AdverbPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{ .MainAndOptionalPhrase = .{
                        .main = .{
                            .index = 1,
                            .isRoot = false,
                        },
                        .optional = .{
                            .index = 0,
                            .isRoot = false,
                        },
                    } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "big",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 1, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.AdjectivePhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{ .MainAndOptionalPhrase = .{
                        .main = .{
                            .index = 0,
                            .isRoot = false,
                        },
                        .optional = null,
                    } },
                    .is_root = false,
                },
            },
        },
    };

    try testParseAdjectiveNodes(&cases, allocator);
}

fn testParseVerbNodes(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseVerb(0) orelse {
            std.debug.print("Failed to parse verb for input: {s}\n", .{case.text});
            return error.Failure;
        };

        std.debug.print("Parsed result: {any}\n", .{result});
        std.debug.print("Expected result: {any}\n", .{case.result});

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Verb Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        // 動詞単体
        .{
            .text = "give",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 1, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.SVOVerb,
            },
            .expected_nodes = &.{
                // give (identifier)
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVOVerb,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                // give (main verb phrase)
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVOVerb,
                    .data = SubAstStructs{ .MainAndOptionalPhrase = .{
                        .main = SubNodeIndex{ .index = 0, .isRoot = false },
                        .optional = null,
                    } },
                    .is_root = false,
                },
            },
        },

        // 句動詞例: "run into"
        .{
            .text = "give back",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 2, .isRoot = false },
                .next_token_index = 2,
                .tag = SubNodeTag.SVOVerb,
            },
            .expected_nodes = &.{
                // run (identifier)
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVOVerb,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                // into (verb particle/optional)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.VerbParticle, // optionalもmainと同じタグ
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                // run into (main+optional)
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVOVerb,
                    .data = SubAstStructs{ .MainAndOptionalPhrase = .{
                        .main = SubNodeIndex{ .index = 0, .isRoot = false },
                        .optional = SubNodeIndex{ .index = 1, .isRoot = false },
                    } },
                    .is_root = false,
                },
            },
        },
        // 必要に応じて五文型や特殊動詞（let, define...）も追加
    };

    try testParseVerbNodes(&cases, allocator);
}

fn testParseAdverbNodes(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseAdverb(0) orelse {
            std.debug.print("Failed to parse adverb for input: {s}\n", .{case.text});
            return error.Failure;
        };

        std.debug.print("Parsed result: {any}\n", .{result});
        std.debug.print("Expected result: {any}\n", .{case.result});

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Adverb Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        .{
            .text = "then",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.AdverbPhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.AdverbPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "more",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.AdverbPhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.AdverbPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "most",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.AdverbPhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.AdverbPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "otherwise",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.AdverbPhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.AdverbPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        // 必要なら他の副詞やエラーケースも追加可
    };

    try testParseAdverbNodes(&cases, allocator);
}

fn testParseInfinitiveHeadNodes(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseInfinitiveHead(0) orelse {
            std.debug.print("Failed to parse infinitive head for input: {s}\n", .{case.text});
            return error.Failure;
        };

        std.debug.print("Parsed result: {any}\n", .{result});
        std.debug.print("Expected result: {any}\n", .{case.result});

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Infinitive Head Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        .{
            .text = "to call",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.InfinitiveHead,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.InfinitiveHead,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "to go",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.InfinitiveHead,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.InfinitiveHead,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        // 必要に応じてエラーケースや複数パターンを追加可能
    };

    try testParseInfinitiveHeadNodes(&cases, allocator);
}

fn testParseGerundNodes(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseGerund(0) orelse {
            std.debug.print("Failed to parse gerund for input: {s}\n", .{case.text});
            return error.Failure;
        };

        std.debug.print("Parsed result: {any}\n", .{result});
        std.debug.print("Expected result: {any}\n", .{case.result});

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Gerund Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        .{
            .text = "repeating",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 1, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.SVOGerundVerb, // ←astのreplaceGerundVerbKindが返すタグを使用
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVOGerundVerb,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVOGerundVerb,
                    .data = SubAstStructs{ .MainAndOptionalPhrase = .{
                        .main = SubNodeIndex{ .index = 0, .isRoot = false },
                        .optional = null,
                    } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "repeating back",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 2, .isRoot = false },
                .next_token_index = 2,
                .tag = SubNodeTag.SVOGerundVerb,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVOGerundVerb,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.VerbParticle, // optionalもmainと同じタグ
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVOGerundVerb,
                    .data = SubAstStructs{ .MainAndOptionalPhrase = .{
                        .main = SubNodeIndex{ .index = 0, .isRoot = false },
                        .optional = SubNodeIndex{ .index = 1, .isRoot = false },
                    } },
                    .is_root = false,
                },
            },
        },
    };

    try testParseGerundNodes(&cases, allocator);
}

fn testParseOnlyNounPhraseNodes(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseOnlyNounPhrase(0) orelse {
            std.debug.print("Failed to parse noun phrase for input: {s}\n", .{case.text});
            return error.Failure;
        };

        std.debug.print("Parsed result: {any}\n", .{result});
        std.debug.print("Expected result: {any}\n", .{case.result});

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "OnlyNounPhrase Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        // 1. a svoc verb
        .{
            .text = "a svoc verb",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 3, .isRoot = false },
                .next_token_index = 3,
                .tag = SubNodeTag.NounPhrase,
            },
            .expected_nodes = &.{
                // "svoc" noun
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{
                        .MainAndOptionalPhrase = .{
                            .main = SubNodeIndex{ .index = 0, .isRoot = false }, // "svoc"
                            .optional = null,
                        },
                    },
                    .is_root = false,
                },
                // "verb" noun
                SubNode{
                    .startTokenIndex = 2,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 2 } },
                    .is_root = false,
                },
                // NounPhrase node
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .NounPhrase = .{
                            .article = 0, // "a" is at index 0
                            .modifiers = .{
                                .start = SubNodeIndex{ .index = 1, .isRoot = false }, // svoc
                                .end = SubNodeIndex{ .index = 1, .isRoot = false }, // "svoc"
                            },
                            .noun = SubNodeIndex{ .index = 2, .isRoot = false }, // "verb"のノード
                        },
                    },
                    .is_root = false,
                },
            },
        },
        // 2. the explanation
        .{
            .text = "the explanation",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 1, .isRoot = false },
                .next_token_index = 2,
                .tag = SubNodeTag.NounPhrase,
            },
            .expected_nodes = &.{
                // "explanation" noun
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                // NounPhrase node
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .NounPhrase = .{
                            .article = 0, // "the" is at index 0
                            .modifiers = null,
                            .noun = SubNodeIndex{ .index = 0, .isRoot = false }, // "explanation"のノード（ノードリストではindex 0になる）
                        },
                    },
                    .is_root = false,
                },
            },
        },
        // 3. a more big svoc verb
        .{
            .text = "a more big svoc verb",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 6, .isRoot = false },
                .next_token_index = 5,
                .tag = SubNodeTag.NounPhrase,
            },
            .expected_nodes = &.{
                // "more" (adverb, 形容詞修飾)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.AdverbPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                // "big" (adjective)
                SubNode{
                    .startTokenIndex = 2,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 2 } },
                    .is_root = false,
                },
                // "svoc" noun
                SubNode{
                    .startTokenIndex = 3,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 3 } },
                    .is_root = false,
                },
                // "big"の形容詞句（more+big）
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{
                        .MainAndOptionalPhrase = .{
                            .main = SubNodeIndex{ .index = 1, .isRoot = false }, // "big"
                            .optional = SubNodeIndex{ .index = 0, .isRoot = false }, // "more"
                        },
                    },
                    .is_root = false,
                },
                // "svoc"の形容詞句 svoc
                SubNode{
                    .startTokenIndex = 3,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{
                        .MainAndOptionalPhrase = .{
                            .main = SubNodeIndex{ .index = 2, .isRoot = false }, // "svoc"
                            .optional = null,
                        },
                    },
                    .is_root = false,
                },
                // "verb" noun
                SubNode{
                    .startTokenIndex = 4,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 4 } },
                    .is_root = false,
                },
                // NounPhrase node
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .NounPhrase = .{
                            .article = 0, // "a" index
                            .modifiers = .{
                                .start = SubNodeIndex{ .index = 3, .isRoot = false }, // AdjectivePhrase(more+big)
                                .end = SubNodeIndex{ .index = 4, .isRoot = false },
                            },
                            .noun = SubNodeIndex{ .index = 5, .isRoot = false }, // "verb"
                        },
                    },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "a more big more svoc verb",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 7, .isRoot = false },
                .next_token_index = 6,
                .tag = SubNodeTag.NounPhrase,
            },
            .expected_nodes = &.{
                // "more" (adverb, 形容詞修飾)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.AdverbPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                // "big" (adjective)
                SubNode{
                    .startTokenIndex = 2,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 2 } },
                    .is_root = false,
                },
                // "more" (adverb, 2回目)
                SubNode{
                    .startTokenIndex = 3,
                    .tag = SubNodeTag.AdverbPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 3 } },
                    .is_root = false,
                },
                // "svoc" (adjective)
                SubNode{
                    .startTokenIndex = 4,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 4 } },
                    .is_root = false,
                },
                // "big"の形容詞句（more+big）
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{
                        .MainAndOptionalPhrase = .{
                            .main = SubNodeIndex{ .index = 1, .isRoot = false }, // "big"
                            .optional = SubNodeIndex{ .index = 0, .isRoot = false }, // "more"
                        },
                    },
                    .is_root = false,
                },
                // "svoc"の形容詞句（more+svoc）
                SubNode{
                    .startTokenIndex = 3,
                    .tag = SubNodeTag.AdjectivePhrase,
                    .data = SubAstStructs{
                        .MainAndOptionalPhrase = .{
                            .main = SubNodeIndex{ .index = 3, .isRoot = false }, // "big"
                            .optional = SubNodeIndex{ .index = 2, .isRoot = false }, // "more"
                        },
                    },
                    .is_root = false,
                },
                // "verb" (noun, 最後)
                SubNode{
                    .startTokenIndex = 5,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 5 } },
                    .is_root = false,
                },
                // 全体をまとめるNounPhraseノード
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .NounPhrase = .{
                            .article = 0, // index of "a"
                            .modifiers = .{
                                .start = SubNodeIndex{ .index = 4, .isRoot = false }, // "more big"
                                .end = SubNodeIndex{ .index = 5, .isRoot = false }, // "more svoc"
                            },
                            .noun = SubNodeIndex{ .index = 6, .isRoot = false }, // "verb"
                        },
                    },
                    .is_root = false,
                },
            },
        },
    };

    try testParseOnlyNounPhraseNodes(&cases, allocator);
}

fn testComparativeCases(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        // 比較パターンのメソッドを分岐
        const result = subParser.parseComparativePhrase(0) orelse {
            std.debug.print("Failed to parse comparative phrase for input: {s}\n", .{case.text});
            return error.Failure;
        };

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Comparative and Superlative Phrase Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        // bigger than
        .{
            .text = "bigger than",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 2,
                .tag = SubNodeTag.ComparativePhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.ComparativePhrase,
                    .data = SubAstStructs{
                        .OpAndVector = .{
                            .op = 0, // "bigger"
                            .vector = 1, // "than"
                        },
                    },
                    .is_root = false,
                },
            },
        },
        // more big than
        .{
            .text = "more big than",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 3,
                .tag = SubNodeTag.ComparativePhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.ComparativePhrase,
                    .data = SubAstStructs{
                        .OpAndVector = .{
                            .op = 1, // "big"
                            .vector = 2, // "than"
                        },
                    },
                    .is_root = false,
                },
            },
        },
        // smaller than
        .{
            .text = "smaller than",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 2,
                .tag = SubNodeTag.ComparativePhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.ComparativePhrase,
                    .data = SubAstStructs{
                        .OpAndVector = .{
                            .op = 0, // "smaller"
                            .vector = 1, // "than"
                        },
                    },
                    .is_root = false,
                },
            },
        },
        // as big as
        .{
            .text = "as big as",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 3,
                .tag = SubNodeTag.ComparativePhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.ComparativePhrase,
                    .data = SubAstStructs{
                        .OpAndVector = .{
                            .op = 1, // "big"
                            .vector = 2, // "as"
                        },
                    },
                    .is_root = false,
                },
            },
        },
        // the biggest of
        .{
            .text = "the biggest of",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 3,
                .tag = SubNodeTag.ComparativePhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.ComparativePhrase,
                    .data = SubAstStructs{
                        .OpAndVector = .{
                            .op = 1, // "biggest"
                            .vector = 2, // "of"
                        },
                    },
                    .is_root = false,
                },
            },
        },
        // the most big of
        .{
            .text = "the most big of",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 4,
                .tag = SubNodeTag.ComparativePhrase,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.ComparativePhrase,
                    .data = SubAstStructs{
                        .OpAndVector = .{
                            .op = 2, // "big"
                            .vector = 3, // "of"
                        },
                    },
                    .is_root = false,
                },
            },
        },
    };

    try testComparativeCases(&cases, allocator);
}

fn testPrepositionalCases(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parsePrepositionalPhrase(0) orelse {
            std.debug.print("Failed to parse prepositional phrase for input: {s}\n", .{case.text});
            return error.Failure;
        };

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Prepositional Phrase Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        // with
        .{
            .text = "with book",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 2, .isRoot = false },
                .next_token_index = 2,
                .tag = SubNodeTag.PrepositionalPhrase,
            },
            .expected_nodes = &.{
                // book (identifier)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                // book (noun phrase)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .NounPhrase = .{
                            .article = null,
                            .modifiers = null,
                            .noun = SubNodeIndex{ .index = 0, .isRoot = false }, // "book"のIdentifierノード
                        },
                    },
                    .is_root = false,
                },
                // with book (prepositional phrase)
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.PrepositionalPhrase,
                    .data = SubAstStructs{
                        .OpAndNode = .{
                            .op = 0, // "with"
                            .node = SubNodeIndex{ .index = 1, .isRoot = false }, // "book"のNounPhraseノード
                        },
                    },
                    .is_root = false,
                },
            },
        },
        // as
        .{
            .text = "as student",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 2, .isRoot = false },
                .next_token_index = 2,
                .tag = SubNodeTag.PrepositionalPhrase,
            },
            .expected_nodes = &.{
                // student (identifier)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                // student (noun phrase)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .NounPhrase = .{
                            .article = null,
                            .modifiers = null,
                            .noun = SubNodeIndex{ .index = 0, .isRoot = false }, // "student"のIdentifierノード
                        },
                    },
                    .is_root = false,
                },
                // as student (prepositional phrase)
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.PrepositionalPhrase,
                    .data = SubAstStructs{
                        .OpAndNode = .{
                            .op = 0, // "as"
                            .node = SubNodeIndex{ .index = 1, .isRoot = false }, // "student"のNounPhraseノード
                        },
                    },
                    .is_root = false,
                },
            },
        },
        // of
        .{
            .text = "of explanation",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 2, .isRoot = false },
                .next_token_index = 2,
                .tag = SubNodeTag.PrepositionalPhrase,
            },
            .expected_nodes = &.{
                // explanation (identifier)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                // explanation (noun phrase)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .NounPhrase = .{
                            .article = null,
                            .modifiers = null,
                            .noun = SubNodeIndex{ .index = 0, .isRoot = false }, // "explanation"
                        },
                    },
                    .is_root = false,
                },
                // of explanation (prepositional phrase)
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.PrepositionalPhrase,
                    .data = SubAstStructs{
                        .OpAndNode = .{
                            .op = 0, // "of"
                            .node = SubNodeIndex{ .index = 1, .isRoot = false },
                        },
                    },
                    .is_root = false,
                },
            },
        },
        // to
        .{
            .text = "to school",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 2, .isRoot = false },
                .next_token_index = 2,
                .tag = SubNodeTag.PrepositionalPhrase,
            },
            .expected_nodes = &.{
                // school (identifier)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                // school (noun phrase)
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .NounPhrase = .{
                            .article = null,
                            .modifiers = null,
                            .noun = SubNodeIndex{ .index = 0, .isRoot = false },
                        },
                    },
                    .is_root = false,
                },
                // to school (prepositional phrase)
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.PrepositionalPhrase,
                    .data = SubAstStructs{
                        .OpAndNode = .{
                            .op = 0, // "to"
                            .node = SubNodeIndex{ .index = 1, .isRoot = false },
                        },
                    },
                    .is_root = false,
                },
            },
        },
    };

    try testPrepositionalCases(&cases, allocator);
}

fn testPureNounListCases(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parsePureNounWithPureList(0) orelse {
            std.debug.print("Failed to parse pure noun list for input: {s}\n", .{case.text});
            return error.Failure;
        };

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Pure Noun List Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        .{
            .text = "book, pen, dog",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 3, .isRoot = false },
                .next_token_index = 5, // 0:book, 1:,, 2:pen, 3:,, 4:dog, 5:EOF
                .tag = SubNodeTag.NounPhrase,
            },
            .expected_nodes = &.{
                // book
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                // pen
                SubNode{
                    .startTokenIndex = 2,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 2 } },
                    .is_root = false,
                },
                // dog
                SubNode{
                    .startTokenIndex = 4,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 4 } },
                    .is_root = false,
                },
                // RangeEnumeration（最初から最後まで）
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .RangeEnumeration = .{
                            .start = SubNodeIndex{ .index = 0, .isRoot = false }, // book
                            .end = SubNodeIndex{ .index = 2, .isRoot = false }, // dog
                        },
                    },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "cat and dog",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 2, .isRoot = false },
                .next_token_index = 3, // 0:cat, 1:and, 2:dog, 3:EOF
                .tag = SubNodeTag.NounPhrase,
            },
            .expected_nodes = &.{
                // cat
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                // dog
                SubNode{
                    .startTokenIndex = 2,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 2 } },
                    .is_root = false,
                },
                // RangeEnumeration
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .RangeEnumeration = .{
                            .start = SubNodeIndex{ .index = 0, .isRoot = false }, // cat
                            .end = SubNodeIndex{ .index = 1, .isRoot = false }, // dog
                        },
                    },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "apple, banana and orange",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 3, .isRoot = false },
                .next_token_index = 5, // 0:apple, 1:,, 2:banana, 3:and, 4:orange, 5:EOF
                .tag = SubNodeTag.NounPhrase,
            },
            .expected_nodes = &.{
                // apple
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                // banana
                SubNode{
                    .startTokenIndex = 2,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 2 } },
                    .is_root = false,
                },
                // orange
                SubNode{
                    .startTokenIndex = 4,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 4 } },
                    .is_root = false,
                },
                // RangeEnumeration
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.NounPhrase,
                    .data = SubAstStructs{
                        .RangeEnumeration = .{
                            .start = SubNodeIndex{ .index = 0, .isRoot = false }, // apple
                            .end = SubNodeIndex{ .index = 2, .isRoot = false }, // orange
                        },
                    },
                    .is_root = false,
                },
            },
        },
    };

    try testPureNounListCases(&cases, allocator);
}

fn testConjunctionCases(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseConjunction(0) orelse {
            std.debug.print("Failed to parse conjunction for input: {s}\n", .{case.text});
            return error.Failure;
        };

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Conjunction Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        .{
            .text = "and",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1, // 0:and, 1:EOF
                .tag = SubNodeTag.Conjunction,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.Conjunction,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "but",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1, // 0:but, 1:EOF
                .tag = SubNodeTag.Conjunction,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.Conjunction,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "otherwise",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1, // 0:otherwise, 1:EOF
                .tag = SubNodeTag.Conjunction,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.Conjunction,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
    };

    try testConjunctionCases(&cases, allocator);
}

fn testSubordinatingConjunctionCases(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseSubordinatingConjunction(0) orelse {
            std.debug.print("Failed to parse subordinating conjunction for input: {s}\n", .{case.text});
            return error.Failure;
        };

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Subordinating Conjunction Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        .{
            .text = "until",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1, // 0:until, 1:EOF
                .tag = SubNodeTag.SubordinatingConjunction,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SubordinatingConjunction,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
    };
    try testSubordinatingConjunctionCases(&cases, allocator);
}

fn testParticipleCases(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseParticiple(0) orelse {
            std.debug.print("Failed to parse participle for input: {s}\n", .{case.text});
            return error.Failure;
        };

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Participle Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        .{
            .text = "called",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 1, .isRoot = false },
                .next_token_index = 1, // 0:called, 1:EOF
                .tag = SubNodeTag.SVCParticiple,
            },
            .expected_nodes = &.{
                // called本体
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVCParticiple, // ここのタグはreplaceParticipleVerbKindで決まる
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                // MainAndOptionalPhrase(本体, optional=null)
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVCParticiple,
                    .data = SubAstStructs{
                        .MainAndOptionalPhrase = .{
                            .main = SubNodeIndex{ .index = 0, .isRoot = false }, // called
                            .optional = null,
                        },
                    },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "called back",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 2, .isRoot = false },
                .next_token_index = 2, // 0:called, 1:back, 2:EOF
                .tag = SubNodeTag.SVCParticiple,
            },
            .expected_nodes = &.{
                // called
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVCParticiple, // ここのタグも同様
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
                // back（VerbParticle, ただし実装によっては違う場合あり）
                SubNode{
                    .startTokenIndex = 1,
                    .tag = SubNodeTag.VerbParticle, // ←通常はVerbParticleだが、実装によってはSVCParticiple
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 1 } },
                    .is_root = false,
                },
                // MainAndOptionalPhrase(本体, optional=back)
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.SVCParticiple,
                    .data = SubAstStructs{
                        .MainAndOptionalPhrase = .{
                            .main = SubNodeIndex{ .index = 0, .isRoot = false }, // called
                            .optional = SubNodeIndex{ .index = 1, .isRoot = false }, // back
                        },
                    },
                    .is_root = false,
                },
            },
        },
    };

    try testParticipleCases(&cases, allocator);
}

fn testMathOperatorCases(
    cases: []const TestSubNodeCase,
    allocator: std.mem.Allocator,
) !void {
    for (cases) |case| {
        var tokens = try ast.getTokenList(allocator, case.text);
        defer tokens.deinit(allocator);
        var subParser = SubParser.init(allocator, tokens);
        defer subParser.deinit();

        const result = subParser.parseMathOperator(0) orelse {
            std.debug.print("Failed to parse math operator for input: {s}\n", .{case.text});
            return error.Failure;
        };

        try std.testing.expectEqual(case.result, result);
        try std.testing.expect(subParser.sub_nodes.len == case.expected_nodes.len);

        for (case.expected_nodes, 0..) |expected, i| {
            const actual = subParser.sub_nodes.get(i);
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "Math Operator Parse" {
    const allocator = std.testing.allocator;

    const cases = [_]TestSubNodeCase{
        .{
            .text = "+",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1, // 0:+, 1:EOF
                .tag = SubNodeTag.MathOperator,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.MathOperator,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "-",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.MathOperator,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.MathOperator,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "*",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.MathOperator,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.MathOperator,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "/",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.MathOperator,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.MathOperator,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "and",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.MathOperator,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.MathOperator,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
        .{
            .text = "or",
            .result = ParseResult{
                .nodes_index = SubNodeIndex{ .index = 0, .isRoot = false },
                .next_token_index = 1,
                .tag = SubNodeTag.MathOperator,
            },
            .expected_nodes = &.{
                SubNode{
                    .startTokenIndex = 0,
                    .tag = SubNodeTag.MathOperator,
                    .data = SubAstStructs{ .Identifier = .{ .tokenIndex = 0 } },
                    .is_root = false,
                },
            },
        },
    };

    try testMathOperatorCases(&cases, allocator);
}
