const std = @import("std");
const Vec = std.ArrayList;

const strs = @import("strings.zig");
const Str = strs.Str;

const ShowErrorAtPoint = @import("errors.zig").ShowErrorAtPoint;

const Tkns = @import("tokens.zig");
const TokenType = Tkns.TokenType;

pub const Token = struct {
    textref: Str,
    ttype: TokenType,
};

///Will greedily consume tokens until it reaches a left facing unbound structural parenthesis or curly brace, or a semi-colon. The semi-colon will be consumed
/// While the others will not. Will insert null-width tokens as is applicable for expressions.
pub fn ExprToTokens(alloc: std.mem.Allocator, expr: *Str) !void {
    var canCast = false;
    var maybeCast = false;
    var callable = false;

    var tkns = Vec(Token).init(alloc);
    var pairs = Vec(Token).init(alloc); 

    while (true) {
        const nToken = try ReadToken(expr);
        const ntype = nToken.ttype;
        
        //<callable>() -> function call
        if (callable and ntype == ._left_paren){
            tkns.append( Token{
                .textref = nToken.textref.NewReader(), 
                .ttype = ._funccall} );
        }
        //<cast?> indent  ||  <cast?> (stuff) -> typecast
        else if (maybeCast and (ntype == ._left_paren or ntype == ._ident)){
            tkns.append( Token{
                .textref = nToken.textref.NewReader(), 
                .ttype = ._typecast} );
            maybeCast = false;
        }
        else if (canCast and ntype == ._right_paren) {
            maybeCast = true;
            canCast = false;
        }

        else if (ntype == ._left_bracket){
            tkns.append( Token{
                .textref = nToken.textref.NewReader(), 
                .ttype = ._arrayindx} );
        }

        if (ntype & Tkns.M_OPERAND == Tkns.OPERAND){
            callable = false;
            canCast = true;
        }
        else if (ntype & Tkns.M_IDENT == Tkns.IDENT){
            callable = true;
            canCast = false;
        }

        //Opening pairs
        if (ntype & Tkns.M_STRUCTURALS == Tkns.STRUCTURAL and ntype & Tkns.CAPRIGHT and !(ntype & Tkns.CAPLEFT)){
            pairs.append(nToken);
        //Closing pairs
        } else if (ntype & Tkns.M_STRUCTURALS == Tkns.STRUCTURAL and ntype & Tkns.CAPRIGHT and !(ntype & Tkns.CAPLEFT)){
            const expect: u64 = @enumFromInt(@intFromEnum(ntype) ^ Tkns.CAPRIGHT ^ Tkns.CAPLEFT);
            const pToken = pairs.pop();
            if (pToken.ttype != expect){
                nToken.textref.Error("Unexpected token `{s}` does not match pairing symbol: `{s}`", .{nToken.textref, pToken.textref});
            }
        }

    }

}

fn ReadToken(expr: *Str) !Token {
    errdefer std.log.debug("Error caught on expression point: {}", .{expr.start});
    errdefer ShowErrorAtPoint(expr, expr.start);

    return ReadKeyword(expr)  
    orelse error.Parse_Failure;
}

fn ReadKeyword(expr: *Str) !?Token {
    inline for (@typeInfo(TokenType).Enum.fields) |flaginfo| {
        const flagname = flaginfo.name;
        const flag = flaginfo.value;
        if(flag & Tkns.M_KWORD == Tkns.KWORD){
            const name = flagname[1..];
            if (try StrStartsWith(expr.*, name)){
                var tknstr = expr.NewReader();
                tknstr.ReadEndAmt(name.len);
                expr.FromEndOf(tknstr);
                return Token {.textref = tknstr, .ttype = @enumFromInt(flag)};
            }
        }
    }
    return null;
}

fn ReadIdent(expr: *Str) !?Token {
    const copy = expr.*;
    errdefer expr.* = copy;

    var tknstr = expr.NewReader();

    const nextchar = tknstr.PeekEndNext();
    if (!strs.IsUA(nextchar)) {
        return null;
    }
    tknstr.ReadAllEnd(strs.IsUAN);
    expr.FromEndOf(tknstr);
    return Token{.textref = tknstr, .ttype = ._ident};
}

fn ReadNum(expr: *Str) !?Token {
    const copy = expr.*;
    errdefer expr.* = copy;

    var tknstr = expr.NewReader();

    var nextchar = tknstr.PeekEndNext();
    if (!strs.IsN(nextchar)) {
        return null;
    }
    tknstr.ReadAllEnd(strs.IsUN);
    
    nextchar = tknstr.PeekEndNext();
    if (strs.IsUA(nextchar)) {
        return error.Not_A_Number;
    }

    expr.FromEndOf(tknstr);
    return Token{.textref = tknstr, .ttype = ._number};
}

fn StrStartsWith(lhs: Str, rhs: []const u8) !bool {
    for (rhs, 0..) |char, ind| {
        if (try lhs.IndexStart(@intCast(ind)) != char) return false;
    }
    return true;
}

test "Keywords" {
    const expect = std.testing.expect;

    var file: Str = Str.FromSlice("");
    var token: ?Token = null;
    inline for (@typeInfo(TokenType).Enum.fields) |flaginfo| {
        if(flaginfo.value & Tkns.M_KWORD == Tkns.KWORD){
            file = Str.FromSlice(flaginfo.name[1..]);
            token = try ReadKeyword(&file);
            expect(token != null and token.?.ttype == @as(TokenType, @enumFromInt(flaginfo.value))) catch |err| {
                std.log.warn("Failed keyword detection for keyword: `{s}`\n", .{flaginfo.name});
                return err;
            };
        }
    }

    file = Str.FromSlice("abc");
    token = try ReadKeyword(&file);
    try expect(token == null);

    file = Str.FromSlice("123");
    token = try ReadKeyword(&file);
    try expect(token == null);
}

test "Identifiers" {
    const expect = std.testing.expect;

    var file: Str = Str.FromSlice("");
    var token: ?Token = null;

    file = Str.FromSlice("abc");
    token = try ReadIdent(&file);
    try expect(token != null and token.?.ttype == ._ident);

    file = Str.FromSlice("123");
    token = try ReadIdent(&file);
    try expect(token == null);

    file = Str.FromSlice("_0123");
    token = try ReadIdent(&file);
    try expect(token != null and token.?.ttype == ._ident);

    file = Str.FromSlice("Capitals");
    token = try ReadIdent(&file);
    try expect(token != null and token.?.ttype == ._ident);

    file = Str.FromSlice("All_ofThe_th1ngs__0");
    token = try ReadIdent(&file);
    try expect(token != null and token.?.ttype == ._ident);

    file = Str.FromSlice("0_bad");
    token = try ReadIdent(&file);
    try expect(token == null);
}

test "Numbers" {
    const expect = std.testing.expect;
    const expectErr = std.testing.expectError;

    var file: Str = Str.FromSlice("");
    var token: ?Token = null;
    var errtoken: error{Not_A_Number}!?Token = null;

    file = Str.FromSlice("abc");
    token = try ReadNum(&file);
    try expect(token == null);

    file = Str.FromSlice("012");
    token = try ReadNum(&file);
    try expect(token != null and token.?.ttype == ._number);

    file = Str.FromSlice("0_");
    token = try ReadNum(&file);
    try expect(token != null and token.?.ttype == ._number);

    file = Str.FromSlice("_0");
    token = try ReadNum(&file);
    try expect(token == null);

    file = Str.FromSlice("0a");
    errtoken = ReadNum(&file);
    try expectErr(error.Not_A_Number, errtoken);
}