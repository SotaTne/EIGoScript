const std = @import("std");
const _tokenizer = @import("tokenizer.zig");
const parser = @import("parser.zig");
const precheck = @import("precheck.zig");
const ast = @import("ast.zig");
const Tokenizer = _tokenizer.Tokenizer;
const Token = _tokenizer.Token;

const Allocator = std.mem.Allocator;
const File = std.fs.File;
const Parser = parser.Parser;
const PreCheck = precheck.PreCheck;

const TokenAndStateList = ast.TokenAndStateList;

pub fn openFile(allocator: *Allocator, path: []const u8) ![:0]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.allocSentinel(u8, @as(usize, @intCast(file_size)), 0);
    errdefer allocator.free(buffer);
    const amt = try file.readAll(buffer);
    if (amt != file_size)
        return error.UnexpectedEndOfFile;

    return buffer;
}

pub fn runCompilerWithStr(allocator: std.mem.Allocator) !void {
    const buffer: [:0]const u8 = "hello world";

    const tokens = ast.getTokenList(allocator, buffer) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };

    const p = Parser.init(tokens);
    var p_check = PreCheck.init(p);
    _ = p_check.parseDefine(0);
    defer tokens.deinit();
}

pub fn runCompiler(allocator: *Allocator, path: []const u8) !void {
    const buffer = try openFile(allocator, path);
    defer allocator.free(buffer);

    const tokenizer = Tokenizer.init(buffer);
    var tokens: []Token = std.ArrayList(Token).init(allocator);
    while (true) {
        const token = tokenizer.next();
        if (token.kind == Token.TokenKind.EOF) break;
        try tokens.append(token);
    }
}

test "runCompiler" {
    runCompilerWithStr(std.testing.allocator) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
}
