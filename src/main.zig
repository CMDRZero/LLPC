const std = @import("std");
const strs = @import("strings.zig");
const Str = strs.Str;

const CharVec = std.ArrayList(u8);
const Vec = std.ArrayList;

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

const Token = struct {
    data: Str,
    dtype: TokenType,
};

const TokenType = enum {
    bin_op,
    un_op,
    fn_call,
    type_cast,
    structural,
    ident,
    num,
    keyword,
};

fn GreedySort(ary: *[][]const u8) @TypeOf(ary) {
    const local = struct{
        fn CompareSliceLen(_: void, lhs: []const u8, rhs: []const u8) bool {
            return lhs.len > rhs.len;
        }
    };
    std.sort.insertion([]const u8, ary.*, {}, local.CompareSliceLen);
    return ary;
}



const ArithOps      = ([_][]const u8 {"+", "-", "*", "/", "%", "<<<", "<<", ">>>", ">>",});
const BitwiseOps    = ([_][]const u8 {"&", "^", "|",});
const ComparisonOps = ([_][]const u8 {"<=", "<", "==", ">=", ">", "!=",});
const BooleanOps    = ([_][]const u8 {"and", "or",});
const UnaryOps      = ([_][]const u8 {"!", "~",});
const FieldOps      = ([_][]const u8 {".*", ".&", ".", ":",});
const AssgOps       = ([_][]const u8 {"=", "+=", "-=", "*=", "/=", "%=", "<<<=", "<<=", ">>>=", ">>=", "&=", "^=", "|=",});
const StructSyms    = ([_][]const u8 {"(", ")", "{", "}", "[", "]", ";", ","});
const KeyWords      = ([_][]const u8 {"if", "while", "do", "var", "const", "static", "struct", "enum", "union", "break", "continue", "true", "false", "goto", "inline", "return", "switch", });


//const Operands = @compileError(@typeName(@TypeOf(ArithOps ++ BitwiseOps)));
const Operands           = ComparisonOps ++ AssgOps ++ FieldOps ++ ArithOps ++ BitwiseOps ++ BooleanOps ++ UnaryOps;

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
    Print(global, "Main started, IO is running\n", .{});
    
    const path = "test.lpc";
    var data = try OpenFile(global, path);
    
    var tokens = Vec(Token).init(global.allocator);

    ExprToTokens(&data, &tokens) catch {DPrint("Tokenization Error\n", .{}); return;};
    tokens.items[3].data.Error("Test Error\n", .{});
    
    for (0..tokens.items.len) |idx| {
        DPrint("Token_{} is {any}\n", .{idx, tokens.items[idx]});
    }
    
    DPrint("data is {any}\n", .{data});
}

//  * * * * * * * * * * * * * * * * * * * *          * * * * * * * * * * * * * * * * * * * *  
// * * * * * * * * * * * * * * * * * * * * * Funcs  * * * * * * * * * * * * * * * * * * * * * 
//  * * * * * * * * * * * * * * * * * * * *          * * * * * * * * * * * * * * * * * * * * 


fn OpenFile(global: Global, path: [] const u8) !Str {
    const alloc = global.allocator;
    const slice = try std.fs.cwd().readFileAlloc(alloc, path, 1<<32);
    //const slice = try std.fs.cwd().readFileAllocOptions(alloc, path, 1<<32, null, @alignOf(u8), '\x00');
    const str = Str.FromSlice(slice);
    //try str.PadAtEnd();
    return str;
}

fn ExprToTokens(expr: *Str, tokens: *Vec(Token)) !void {
    while (expr.CanPop()) {
        _ = try expr.CountReadAll(strs.IsWS);
        if(expr.CanPop()){
            try tokens.append(try ReadToken(expr));
        }
    }
    return;
}

fn ReadToken(expr: *Str) !Token {
    errdefer std.log.debug("Error caught on expression point: {}", .{expr.start});
    errdefer ShowErrorAtPoint(expr, expr.start);
    
    return ReadIdent(expr) 
    orelse try ReadNum(expr) 
    orelse ReadOperand(expr)
    orelse ReadStructural(expr)
    orelse error.Parse_Failure;
} 

fn ReadIdent(expr: *Str) ?Token {
    const copy = expr.*;
    errdefer expr.* = copy;

    var tknstr = expr.NewReader();

    const nextchar = tknstr.PeekNext();
    if (!strs.IsUA(nextchar)){
        return null;
    }
    tknstr.ReadAll(strs.IsUAN);
    expr.FromEndOf(tknstr);
    return Token {.data = tknstr, .dtype = .ident};
}

fn ReadNum(expr: *Str) !?Token {
    const copy = expr.*;
    errdefer expr.* = copy;

    var tknstr = expr.NewReader();

    const nextchar = tknstr.PeekNext();
    if (!strs.IsN(nextchar)){
        return null;
        //return error.Not_A_Number;
    }
    tknstr.ReadAll(strs.IsUN);
    expr.FromEndOf(tknstr);
    return Token {.data = tknstr, .dtype = .num};
}

fn ReadOperand(expr: *Str) ?Token {
    var caplen: u32 = 0;
    var foundOp: ?Token = null;
    inline for (Operands) |op| {
        if (op.len <= caplen) break;
        inline for (op, 0..) |char, ind| {
            if (expr.IndexStart(ind) != char) break;
        } else {
            caplen = op.len;
            var tknstr = expr.NewReader();
            tknstr.ReadAmt(op.len);
            expr.FromEndOf(tknstr);
            foundOp = Token {.data = tknstr, .dtype = .bin_op};
        }
    }
    return foundOp;
}

fn ReadStructural(expr: *Str) ?Token {
    var caplen: u32 = 0;
    var foundOp: ?Token = null;
    inline for (StructSyms) |op| {
        if (op.len <= caplen) break;
        inline for (op, 0..) |char, ind| {
            if (expr.IndexStart(ind) != char) break;
        } else {
            caplen = op.len;
            var tknstr = expr.NewReader();
            tknstr.ReadAmt(op.len);
            expr.FromEndOf(tknstr);
            foundOp = Token {.data = tknstr, .dtype = .structural};
        }
    }
    return foundOp;
}

fn ReadKeyword(expr: *Str) ?Token {
    var caplen: u32 = 0;
    var foundOp: ?Token = null;
    inline for (KeyWords) |op| {
        if (op.len <= caplen) break;
        inline for (op, 0..) |char, ind| {
            if (expr.IndexStart(ind) != char) break;
        } else {
            caplen = op.len;
            var tknstr = expr.NewReader();
            tknstr.ReadAmt(op.len);
            expr.FromEndOf(tknstr);
            foundOp = Token {.data = tknstr, .dtype = .keyword};
        }
    }
    return foundOp;
}

/// If the function cannot print to stdout for whatever reason, return error code 74, which seems to be the std-ish error for IO failure, otherwise never err
fn Print(global: Global, comptime format: []const u8, args: anytype) void {
    global.stdout.print(format, args) catch std.posix.exit(74);
}

fn DPrint(comptime format: []const u8, args: anytype) void {
    std.debug.print(format, args);
}

fn ShowErrorAtPoint(expr: *Str, loc: u32) void {
    var linestart: u32 = 0;
    var linenum: u32 = 0;
    for (0..loc) |i| {
        const char = expr.backer[i];
        if (char == '\n' or char == '\r') {
            linestart = @intCast(i+1);
        }
        linenum += @intFromBool(char == '\n');
    }
    var lineend = linestart;
    while (lineend < expr.backer.len and !(expr.backer[lineend] == '\r' or expr.backer[lineend] == '\n')) : (lineend += 1){}
    DPrint("Error on line: {}, col: {}\n\t{s}\n", .{linenum+1, loc-linestart+1, expr.backer[linestart..lineend]});
    const spad = (" " ** 256)[0..loc-linestart];
    DPrint("\t{s}^\n", .{spad});
}