const std = @import("std");
const Vec = std.ArrayList;

const strs = @import("strings.zig");
const Str = strs.Str;

const ShowErrorAtPoint = @import("errors.zig").ShowErrorAtPoint;

const tokenizer = @import("tokenizer.zig");
const Token = tokenizer.Token;

const ast = @import("ast.zig");

///Here I'm using a global struct so I can test using different globals if need be, and so it can be passed around.
///Furthermore:
/// - A function with no global arg is pure
/// - A function that takes global reads only
/// - A function that takes a ptr is global mutating.
pub const Global = struct {
    allocator: std.mem.Allocator,
    stdout: @TypeOf(std.io.getStdOut().writer()),
    stdin: @TypeOf(std.io.getStdIn().reader()),
};

//  * * * * * * * * * * * * * * * * * * * *         * * * * * * * * * * * * * * * * * * * *  
// * * * * * * * * * * * * * * * * * * * * * Main  * * * * * * * * * * * * * * * * * * * * * 
//  * * * * * * * * * * * * * * * * * * * *         * * * * * * * * * * * * * * * * * * * * 

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var pre_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const global: Global = .{
        .allocator = pre_alloc.allocator(),
        .stdout = stdout,
        .stdin = stdin,
    };
    
    const path = "test.lpc";
    var data = try OpenFile(global, path);
    
    var tokens = Vec(Token).init(global.allocator);

    _ = ast.ParseExprToAST(&data, &tokens, global.allocator) catch {DPrint("Tokenization Error\n", .{}); return;};

    //tokenizer.ExprToTokens(&data, &tokens) catch {DPrint("Tokenization Error\n", .{}); return;};

    //tokens.items[3].data.Error("Test Error\n", .{});
    
    for (0..tokens.items.len) |idx| {
        DPrint("Token_{} is {any}\n", .{idx, tokens.items[idx]});
    }

    DPrint("Max Prec is {}", .{ast.maxprec});
}

//  * * * * * * * * * * * * * * * * * * * *          * * * * * * * * * * * * * * * * * * * *  
// * * * * * * * * * * * * * * * * * * * * * Funcs  * * * * * * * * * * * * * * * * * * * * * 
//  * * * * * * * * * * * * * * * * * * * *          * * * * * * * * * * * * * * * * * * * * 


fn OpenFile(global: Global, path: [] const u8) !Str {
    const alloc = global.allocator;
    const slice = try std.fs.cwd().readFileAlloc(alloc, path, 1<<32);
    const str = Str.FromSlice(slice);
    return str;
}

/// If the function cannot print to stdout for whatever reason, return error code 74, which seems to be the std-ish error for IO failure, otherwise never err
fn Print(global: Global, comptime format: []const u8, args: anytype) void {
    global.stdout.print(format, args) catch std.posix.exit(74);
}

fn DPrint(comptime format: []const u8, args: anytype) void {
    std.debug.print(format, args);
}