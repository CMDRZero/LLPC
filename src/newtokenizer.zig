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

///Will greedily consume tokens until it reaches a left facing unbound structural parenthesis, or a semi-colon. The semi-colon will be consumed
/// While the others will not. Will insert null-width tokens as is applicable for expressions.
pub fn ExprToTokens(alloc: std.mem.Allocator, expr: *Str) !Vec(Token) {
    var canCast = true;
    var maybeCast = false;
    var callable = false;
    var unaryCoerce = true;

    const parentype = enum {
        NA,
        Call,
        Cast,
    };

    var tkns = Vec(Token).init(alloc);
    errdefer tkns.deinit();
    var pairs = Vec(Token).init(alloc); 
    var parentypes = Vec(parentype).init(alloc);
    defer pairs.deinit();
    defer parentypes.deinit();

    expr.PopAllFront(strs.IsWS);

    const ret = loop: while (true) {
        const nToken = ReadToken(expr, unaryCoerce) catch |err| {
            expr.Error("Tokenization failed here\n", .{});
            break: loop err;
        };
        expr.PopAllFront(strs.IsWS);
        const ntype = nToken.ttype;
        unaryCoerce = ntype.CanCapRight() or ntype.IsOperand();

        //<callable>() -> function call
        if (callable and ntype == ._left_paren){
            try tkns.append( Token{
                .textref = nToken.textref.NewReader(), 
                .ttype = ._funccall} );
        }
        //<cast?> indent  ||  <cast?> (stuff) -> typecast
        else if (maybeCast and (ntype == ._left_paren or ntype == ._ident)){
            try tkns.append( Token{
                .textref = nToken.textref.NewReader(), 
                .ttype = ._typecast} );
        }
        else if (ntype == ._left_bracket){
            try tkns.append( Token{
                .textref = nToken.textref.NewReader(), 
                .ttype = ._arrayindx} );
        }

        if (ntype.IsOperand()){
            callable = false;
            canCast = true;
        }
        else if (ntype.IsIdent()){
            callable = true;
            canCast = false;
        }

        maybeCast = false;
        
        //Opening pairs
        if (ntype.IsStructural() and ntype.CanCapRight() and !ntype.CanCapLeft()){
            try pairs.append(nToken);
            if (ntype == ._left_paren){
                try parentypes.append(if (canCast) .Cast else .Call);
            } else {
                try parentypes.append(.NA);
            }
        
        //Closing pairs
        } else if (ntype.IsStructural() and !ntype.CanCapRight() and ntype.CanCapLeft()){
            const expect: u64 = ntype.Int() ^ Tkns.CAPRIGHT ^ Tkns.CAPLEFT;
            if (pairs.items.len == 0 and ntype == ._right_paren) break: loop tkns; //If there is an unmatched right parenthesis, this will terminate an expression.
            
            if (pairs.items.len == 0){
                nToken.textref.Error("Unexpected token `{s}` is unpaired", .{nToken.textref});
                return error.Mismatched_Symbol;
            }
            
            const pToken = pairs.pop();
            if (pToken.ttype.Int() != expect) {
                nToken.textref.Error("Unexpected token `{s}` does not match pairing symbol: `{s}`", .{nToken.textref, pToken.textref});
                return error.Mismatched_Symbol;
            }
            
            const ptype = parentypes.pop();
            if (ptype == .Call){
                callable = true;
            } else if (ptype == .Cast){
                maybeCast = true;
            }
        } 

        try tkns.append(nToken);
        if (ntype == ._semicolon){
            break: loop tkns;
        }
    };

    if (pairs.items.len != 0){
        if (!@import("builtin").is_test){
            pairs.items[pairs.items.len - 1].textref.Error("Unpaired\n", .{});
        }
        return error.Unpaired;
    }

    return ret;

}

fn ReadToken(expr: *Str, perferUnary: bool) !Token {
    if (!@import("builtin").is_test){
        errdefer std.log.debug("Error caught on expression point: {}", .{expr.start});
        errdefer ShowErrorAtPoint(expr, expr.start);
    }

    return try ReadOperand(expr, perferUnary)
    orelse try ReadKeyword(expr)  
    orelse try ReadIdent(expr)
    orelse try ReadNum(expr)
    orelse try ReadStructural(expr)
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

fn ReadOperand(expr: *Str, perferUnary: bool) !?Token {
    const copy = expr.*;
    errdefer expr.* = copy;

    var caplen: u32 = 0;
    var capUnary = false;
    var foundOp: ?TokenType = null;
    inline for (Tkns.OpSyms) |pair| {
        const sym = pair.sym;
        const ttype = pair.tkn;
        const isUnary = @intFromEnum(ttype) & Tkns.M_OPTYPE == Tkns.OT_UNARY;
        const pref = perferUnary and isUnary and !capUnary or !perferUnary and !isUnary and capUnary;
        if ((sym.len > caplen or pref and sym.len == caplen) and try StrStartsWith(expr.*, sym)){
            caplen = sym.len;
            foundOp = ttype;
            capUnary = isUnary;
        }
    }
    if (foundOp) |tknid| {
        var tknstr = expr.NewReader();
        tknstr.ReadEndAmt(caplen);
        expr.FromEndOf(tknstr);
        return Token{.textref = tknstr, .ttype = tknid};
    }
    return null;
}

fn ReadStructural(expr: *Str) !?Token {
    const copy = expr.*;
    errdefer expr.* = copy;

    var caplen: u32 = 0;
    var foundOp: ?TokenType = null;
    inline for (Tkns.StructSyms) |pair| {
        const sym = pair.sym;
        const ttype = pair.tkn;
        if (sym.len > caplen and try StrStartsWith(expr.*, sym)){
            caplen = sym.len;
            foundOp = ttype;
        }
    }
    if (foundOp) |tknid| {
        var tknstr = expr.NewReader();
        tknstr.ReadEndAmt(caplen);
        expr.FromEndOf(tknstr);
        return Token{.textref = tknstr, .ttype = tknid};
    }
    return null;
}

fn StrStartsWith(lhs: Str, rhs: []const u8) !bool {
    if (rhs.len > (lhs.end - lhs.start)) return false;
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

test "Operands" {
    const expect = std.testing.expect;

    var file: Str = Str.FromSlice("");
    var token: ?Token = null;

    file = Str.FromSlice("*");
    token = try ReadOperand(&file, false);
    try expect(token != null and token.?.ttype == ._mul);
    
    file = Str.FromSlice("+");
    token = try ReadOperand(&file, false);
    try expect(token != null and token.?.ttype == ._add);

    file = Str.FromSlice("+");
    token = try ReadOperand(&file, true);
    try expect(token != null and token.?.ttype == ._pos);

    file = Str.FromSlice("<<=");
    token = try ReadOperand(&file, true);
    try expect(token != null and token.?.ttype == ._bsl_assg);

    file = Str.FromSlice("or");
    token = try ReadOperand(&file, true);
    try expect(token != null and token.?.ttype == ._kw_or);

    file = Str.FromSlice("if");
    token = try ReadOperand(&file, true);
    try expect(token == null);

    file = Str.FromSlice("012");
    token = try ReadOperand(&file, true);
    try expect(token == null);

    file = Str.FromSlice("@");
    token = try ReadOperand(&file, true);
    try expect(token == null);
}

test "Structurals" {
    const expect = std.testing.expect;

    var file: Str = Str.FromSlice("");
    var token: ?Token = null;

    file = Str.FromSlice("(");
    token = try ReadStructural(&file);
    try expect(token != null and token.?.ttype == ._left_paren);
    
    file = Str.FromSlice("]");
    token = try ReadStructural(&file);
    try expect(token != null and token.?.ttype == ._right_bracket);

    
    file = Str.FromSlice(";");
    token = try ReadStructural(&file);
    try expect(token != null and token.?.ttype == ._semicolon);
}

test "General" {
    const expect = std.testing.expect;
    const expectErr = std.testing.expectError;

    var file: Str = Str.FromSlice("");
    var token: Token = undefined;
    var errtoken: anyerror!Token = undefined;

    file = Str.FromSlice("abc");
    token = try ReadToken(&file, false);
    try expect(token.ttype == ._ident);

    file = Str.FromSlice("0_a");
    errtoken = ReadToken(&file, false);
    try expectErr(error.Not_A_Number, errtoken);

    file = Str.FromSlice("012");
    token = try ReadToken(&file, false);
    try expect(token.ttype == ._number);

    file = Str.FromSlice("if");
    token = try ReadToken(&file, false);
    try expect(token.ttype == ._if);

    file = Str.FromSlice("x");
    token = try ReadToken(&file, false);
    try expect(token.ttype == ._ident);

    file = Str.FromSlice("or");
    token = try ReadToken(&file, false);
    try expect(token.ttype == ._kw_or);

    file = Str.FromSlice("*");
    token = try ReadToken(&file, false);
    try expect(token.ttype == ._mul);

    file = Str.FromSlice("-");
    token = try ReadToken(&file, true);
    try expect(token.ttype == ._neg);

    file = Str.FromSlice("(");
    token = try ReadToken(&file, true);
    try expect(token.ttype == ._left_paren);

    file = Str.FromSlice(";");
    token = try ReadToken(&file, true);
    try expect(token.ttype == ._semicolon);
    
}

test "Multitokens" {
    const expect = std.testing.expect;
    const expectErr = std.testing.expectError;

    var file: Str = Str.FromSlice("");
    const alloc = std.testing.allocator;
    var tokens: Vec(Token) = undefined;
    var errtokens: anyerror!Vec(Token) = undefined;

    file = Str.FromSlice("x + y;");
    tokens = try ExprToTokens(alloc, &file);
    errdefer {
        for (0.., tokens.items) |i, item| {
            std.log.warn("Token_{} is of type: {s}", .{i, @tagName(item.ttype)});
        }
    }


    expect(tokens.items.len == 4) catch |err| {
        std.log.warn("Real length was: {}\n", .{tokens.items.len});
        return err;
    };
    try expect(tokens.items[0].ttype == ._ident);
    try expect(tokens.items[1].ttype == ._add);
    try expect(tokens.items[2].ttype == ._ident);
    try expect(tokens.items[3].ttype == ._semicolon);
    tokens.deinit();


    file = Str.FromSlice("-x -- y (-z)-w;");
    tokens = try ExprToTokens(alloc, &file);

    expect(tokens.items.len == 13) catch |err| {
        std.log.warn("Real length was: {}\n", .{tokens.items.len});
        return err;
    };
    try expect(tokens.items[0].ttype == ._neg);
    try expect(tokens.items[1].ttype == ._ident);
    try expect(tokens.items[2].ttype == ._sub);
    try expect(tokens.items[3].ttype == ._neg);
    try expect(tokens.items[4].ttype == ._ident);
    try expect(tokens.items[5].ttype == ._funccall);
    try expect(tokens.items[6].ttype == ._left_paren);
    try expect(tokens.items[7].ttype == ._neg);
    try expect(tokens.items[8].ttype == ._ident);
    try expect(tokens.items[9].ttype == ._right_paren);
    try expect(tokens.items[10].ttype == ._sub);
    try expect(tokens.items[11].ttype == ._ident);
    try expect(tokens.items[12].ttype == ._semicolon);
    tokens.deinit();


    file = Str.FromSlice("(int)f(x, y);");
    tokens = try ExprToTokens(alloc, &file);

    expect(tokens.items.len == 12) catch |err| {
        std.log.warn("Real length was: {}\n", .{tokens.items.len});
        return err;
    };

    try expect(tokens.items[0].ttype == ._left_paren);
    try expect(tokens.items[1].ttype == ._ident);
    try expect(tokens.items[2].ttype == ._right_paren);
    try expect(tokens.items[3].ttype == ._typecast);
    try expect(tokens.items[4].ttype == ._ident);
    try expect(tokens.items[5].ttype == ._funccall);
    try expect(tokens.items[6].ttype == ._left_paren);
    try expect(tokens.items[7].ttype == ._ident);
    try expect(tokens.items[8].ttype == ._comma);
    try expect(tokens.items[9].ttype == ._ident);
    try expect(tokens.items[10].ttype == ._right_paren);
    try expect(tokens.items[11].ttype == ._semicolon);
    tokens.deinit();



    file = Str.FromSlice("x ~ y;");
    tokens = try ExprToTokens(alloc, &file);

    expect(tokens.items.len == 4) catch |err| {
        std.log.warn("Real length was: {}\n", .{tokens.items.len});
        return err;
    };

    try expect(tokens.items[0].ttype == ._ident);
    try expect(tokens.items[1].ttype == ._tilde);
    try expect(tokens.items[2].ttype == ._ident);
    try expect(tokens.items[3].ttype == ._semicolon);
    tokens.deinit();

    

    file = Str.FromSlice("(int)ary[idx](x);");
    tokens = try ExprToTokens(alloc, &file);

    expect(tokens.items.len == 14) catch |err| {
        std.log.warn("Real length was: {}\n", .{tokens.items.len});
        return err;
    };

    try expect(tokens.items[0].ttype == ._left_paren);
    try expect(tokens.items[1].ttype == ._ident);
    try expect(tokens.items[2].ttype == ._right_paren);
    try expect(tokens.items[3].ttype == ._typecast);
    try expect(tokens.items[4].ttype == ._ident);
    try expect(tokens.items[5].ttype == ._arrayindx);
    try expect(tokens.items[6].ttype == ._left_bracket);
    try expect(tokens.items[7].ttype == ._ident);
    try expect(tokens.items[8].ttype == ._right_bracket);
    try expect(tokens.items[9].ttype == ._funccall);
    try expect(tokens.items[10].ttype == ._left_paren);
    try expect(tokens.items[11].ttype == ._ident);
    try expect(tokens.items[12].ttype == ._right_paren);
    try expect(tokens.items[13].ttype == ._semicolon);
    tokens.deinit();

    
    

    file = Str.FromSlice("+(a)a + (a) + a(a);");
    tokens = try ExprToTokens(alloc, &file);

    expect(tokens.items.len == 17) catch |err| {
        std.log.warn("Real length was: {}\n", .{tokens.items.len});
        return err;
    };

    try expect(tokens.items[0].ttype == ._pos);
    try expect(tokens.items[1].ttype == ._left_paren);
    try expect(tokens.items[2].ttype == ._ident);
    try expect(tokens.items[3].ttype == ._right_paren);
    try expect(tokens.items[4].ttype == ._typecast);
    try expect(tokens.items[5].ttype == ._ident);
    try expect(tokens.items[6].ttype == ._add);
    try expect(tokens.items[7].ttype == ._left_paren);
    try expect(tokens.items[8].ttype == ._ident);
    try expect(tokens.items[9].ttype == ._right_paren);
    try expect(tokens.items[10].ttype == ._add);
    try expect(tokens.items[11].ttype == ._ident);
    try expect(tokens.items[12].ttype == ._funccall);
    try expect(tokens.items[13].ttype == ._left_paren);
    try expect(tokens.items[14].ttype == ._ident);
    try expect(tokens.items[15].ttype == ._right_paren);
    try expect(tokens.items[16].ttype == ._semicolon);
    tokens.deinit();



    file = Str.FromSlice("x and y)");
    tokens = try ExprToTokens(alloc, &file);

    expect(tokens.items.len == 3) catch |err| {
        std.log.warn("Real length was: {}\n", .{tokens.items.len});
        return err;
    };

    try expect(tokens.items[0].ttype == ._ident);
    try expect(tokens.items[1].ttype == ._kw_and);
    try expect(tokens.items[2].ttype == ._ident);
    tokens.deinit();

    


    file = Str.FromSlice("1 + 2");
    errtokens = ExprToTokens(alloc, &file);

    try expectErr(error.Parse_Failure, errtokens);
    
    


    file = Str.FromSlice("1 + 2_a");
    errtokens = ExprToTokens(alloc, &file);

    try expectErr(error.Not_A_Number, errtokens);



    file = Str.FromSlice("1 + 2 * (");
    errtokens = ExprToTokens(alloc, &file);

    try expectErr(error.Unpaired, errtokens);

    


    file = Str.FromSlice("assert sum == 4;");
    tokens = try ExprToTokens(alloc, &file);

    expect(tokens.items.len == 5) catch |err| {
        std.log.warn("Real length was: {}\n", .{tokens.items.len});
        return err;
    };

    try expect(tokens.items[0].ttype == ._assert);
    try expect(tokens.items[1].ttype == ._ident);
    try expect(tokens.items[2].ttype == ._eq);
    try expect(tokens.items[3].ttype == ._number);
    try expect(tokens.items[4].ttype == ._semicolon);
    tokens.deinit();



    file = Str.FromSlice("std:println(msg);");
    tokens = try ExprToTokens(alloc, &file);

    expect(tokens.items.len == 8) catch |err| {
        std.log.warn("Real length was: {}\n", .{tokens.items.len});
        return err;
    };

    try expect(tokens.items[0].ttype == ._ident);
    try expect(tokens.items[1].ttype == ._colon);
    try expect(tokens.items[2].ttype == ._ident);
    try expect(tokens.items[3].ttype == ._funccall);
    try expect(tokens.items[4].ttype == ._left_paren);
    try expect(tokens.items[5].ttype == ._ident);
    try expect(tokens.items[6].ttype == ._right_paren);
    try expect(tokens.items[7].ttype == ._semicolon);
    tokens.deinit();
}