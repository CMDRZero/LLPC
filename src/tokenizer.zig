const std = @import("std");
const Vec = std.ArrayList;

const strs = @import("strings.zig");
const Str = strs.Str;

const ShowErrorAtPoint = @import("errors.zig").ShowErrorAtPoint;

pub const Token = struct {
    data: Str,
    dtype: TokenType,
    flags: TokenFlag,
};

const TokenType = enum {
    bin_op,
    un_op,
    fn_call,
    type_cast,
    struct_inst,
    structural,
    ident,
    num,
    keyword,

    pub fn UnaryCoersive(self: TokenType) bool {
        return switch (self) {
            .bin_op => true,
            .un_op => true,
            .keyword => true,
            else => false,
        };
    }
};

const TokenFlag = packed struct {
    //Is the token coersible to a value type? 
    isVal: bool,
    //Can the token reduce to the left?
    canRedLeft: bool,
    //Can the token reduce to the right?
    canRedRight: bool,

    const Normal: TokenFlag = .{.isVal = true, .canRedLeft = true, .canRedRight = true};
    const Left: TokenFlag = .{.isVal = true, .canRedLeft = false, .canRedRight = true};
    const Right: TokenFlag = .{.isVal = true, .canRedLeft = true, .canRedRight = false};
    const None: TokenFlag = .{.isVal = false, .canRedLeft = false, .canRedRight = false};
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


const ArithOps       = ([_][]const u8 {"+", "-", "*", "/", "%", "<<<", "<<", ">>>", ">>",});
const BitwiseOps     = ([_][]const u8 {"&", "^", "|",});
const ComparisonOps  = ([_][]const u8 {"<=", "<", "==", ">=", ">", "!=",});
const BooleanOps     = ([_][]const u8 {"and", "or",});
const UnaryOps       = ([_][]const u8 {"!", "~", "+", "-"});
const FieldOps       = ([_][]const u8 {".*", ".&", ".", ":",});
const AssgOps        = ([_][]const u8 {"=", "+=", "-=", "*=", "/=", "%=", "<<<=", "<<=", ">>>=", ">>=", "&=", "^=", "|=",});
const RDirStructSyms = ([_][]const u8 {"(", "{", "[",});
const LDirStructSyms = ([_][]const u8 {")", "}", "]",});
const CDirStructSyms = ([_][]const u8 {";", ",",});
const StructSyms                    = LDirStructSyms ++ RDirStructSyms ++ CDirStructSyms;
const KeyWords       = ([_][]const u8 {"if", "while", "do", "var", "const", "mut", "static", "struct", "enum", "union", "break", "continue", "true", "false", "goto", "inline", "return", "switch", "assert", });

const BinaryOperands     = ComparisonOps ++ AssgOps ++ FieldOps ++ ArithOps ++ BitwiseOps ++ BooleanOps;
const Operands           = BinaryOperands ++ UnaryOps;


pub fn ExprToTokens(expr: *Str, tokens: *Vec(Token)) !void {
    try ExprToTokensRaw(expr, tokens);
    ExprRefineTokens(tokens.*);
    return;
}

fn ExprToTokensRaw(expr: *Str, tokens: *Vec(Token)) !void {
    while (expr.CanPop()) {
        _ = try expr.CountReadAll(strs.IsWS);
        if(expr.CanPop()){
            const tkn = try ReadToken(expr);
            try tokens.append(tkn);
            if (StrEq(tkn.data, ";")){
                return;
            }
        }
        
    } else {
        return error.Expected_Token_Found_EOF;
    }
    return;
}

fn ExprRefineTokens(tkns: Vec(Token)) void {
    var qPrevtkn: ?Token = null;
    for (tkns.items) |*tkn| {
        const canCoerce = CanCoerceToUnary(tkn.*);
        var allowCoerce = false;
        if (qPrevtkn) |prevtkn| {
            allowCoerce = prevtkn.dtype.UnaryCoersive();
            allowCoerce = allowCoerce or !prevtkn.flags.canRedRight;
        } else {
            allowCoerce = true;
        }

        if (canCoerce and allowCoerce){
            tkn.dtype = .un_op;
        }

        qPrevtkn = tkn.*;
    }
}

fn CanCoerceToUnary(tkn: Token) bool {
    inline for (UnaryOps) |op| {
        if (StrEq(tkn.data, op)) return true;
    }
    return false;
}

fn StrEq(lhs: Str, rhs: []const u8) bool {
    if (lhs.end - lhs.start != rhs.len) return false;
    for (rhs, 0..) |char, ind| {
        if (lhs.IndexStart(@intCast(ind)) != char) return false;
    }
    return true;
}

fn FrontStrEq(lhs: Str, rhs: []const u8) bool {
    for (rhs, 0..) |char, ind| {
        if (lhs.IndexStart(@intCast(ind)) != char) return false;
    }
    return true;
}

fn ReadToken(expr: *Str) !Token {
    errdefer std.log.debug("Error caught on expression point: {}", .{expr.start});
    errdefer ShowErrorAtPoint(expr, expr.start);
    
    return ReadKeyword(expr)
    orelse ReadIdent(expr) 
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
    return Token {.data = tknstr, .dtype = .ident, .flags = TokenFlag.Normal};
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
    return Token {.data = tknstr, .dtype = .num, .flags = TokenFlag.Normal};
}

fn ReadOperand(expr: *Str) ?Token {
    var caplen: u32 = 0;
    var foundOp: ?Token = null;
    inline for (BinaryOperands) |op| {
        if (op.len <= caplen) break;
        if (FrontStrEq(expr.*, op)){
            caplen = op.len;
            var tknstr = expr.NewReader();
            tknstr.ReadAmt(op.len);
            expr.FromEndOf(tknstr);
            foundOp = Token {.data = tknstr, .dtype = .bin_op, .flags = TokenFlag.Normal};
        }
    }
    inline for (UnaryOps) |op| {
        if (op.len <= caplen) break;
        if (FrontStrEq(expr.*, op)){
            caplen = op.len;
            var tknstr = expr.NewReader();
            tknstr.ReadAmt(op.len);
            expr.FromEndOf(tknstr);
            foundOp = Token {.data = tknstr, .dtype = .un_op, .flags = TokenFlag.Normal};
        }
    }
    return foundOp;
}

fn ReadStructural(expr: *Str) ?Token {
    var caplen: u32 = 0;
    var foundOp: ?Token = null;
    inline for (LDirStructSyms) |op| {
        if (op.len <= caplen) break;
        if (FrontStrEq(expr.*, op)){
            caplen = op.len;
            var tknstr = expr.NewReader();
            tknstr.ReadAmt(op.len);
            expr.FromEndOf(tknstr);
            foundOp = Token {.data = tknstr, .dtype = .structural, .flags = TokenFlag.Left};
        }
    }
    inline for (RDirStructSyms) |op| {
        if (op.len <= caplen) break;
        if (FrontStrEq(expr.*, op)){
            caplen = op.len;
            var tknstr = expr.NewReader();
            tknstr.ReadAmt(op.len);
            expr.FromEndOf(tknstr);
            foundOp = Token {.data = tknstr, .dtype = .structural, .flags = TokenFlag.Right};
        }
    }
    inline for (CDirStructSyms) |op| {
        if (op.len <= caplen) break;
        if (FrontStrEq(expr.*, op)){
            caplen = op.len;
            var tknstr = expr.NewReader();
            tknstr.ReadAmt(op.len);
            expr.FromEndOf(tknstr);
            foundOp = Token {.data = tknstr, .dtype = .structural, .flags = TokenFlag.None};
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
            foundOp = Token {.data = tknstr, .dtype = .keyword, .flags = TokenFlag.Normal};
        }
    }
    return foundOp;
}