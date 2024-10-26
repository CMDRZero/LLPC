const std = @import("std");
const Vec = std.ArrayList;
const DLL = std.DoublyLinkedList;

const strs = @import("strings.zig");
const Str = strs.Str;
const zstr = [] const u8;   //Zig String type

const ShowErrorAtPoint = @import("errors.zig").ShowErrorAtPoint;

const Tkns = @import("tokens.zig");
const TokenType = Tkns.TokenType;
const Tknz = @import("newtokenizer.zig");
const Token = Tknz.Token;

const Exprnode = struct {
    dtype: Dtype,
    textref: Str,
    value: ?*anyopaque,
    children: Vec(Exprnode),
    token: Token,

    fn deinit(self: *Exprnode) void {
        for (self.children.items) |*child| {
            child.deinit();
        }
        self.children.deinit();
    }
};

const Dtype = struct {
    root: roottype,
    rootqualf: TypeQualf,
    mods: Vec(TypeMod),
    modqualfs: Vec(TypeQualf),  //Has same size as `mods`

    const roottype = union(enum) { 
        int: struct {
            width: u8,
            signed: bool, }, 
        ustruct: struct {
            name: []const u8, } };
    const TypeMod = union(enum) {
        none: void,
        array: struct {
            length: u16,
        },
        slice: void,    //Just a ptr and length, both u16s
        nullable: void, //Wrap the type in a bool which stores if null. For ints with a short length, pack as lowest bit, for ptrs, store as being 0
        pointer: void,  //A pointer type, internally a u16
    };

    const TypeQualf = enum {
        _none,
        _const,
        _mut,
    };
};

const Var = struct {
    name: zstr,
    dtype: Dtype,
    begin: ?u32, //The index of the expression this variable enters before
    end: ?u32,   //The index of the expression this variable is last used in
};

const Arg = struct {
    ivar: Var,
    AquisType: enum {aqConst, aqCopy, aqMut},
};

const Program = struct {
    name: zstr,
    decls: [] TLDecl,
};

const TLDecl = union (enum) {
    _func: Func,
    _val: Val,
    _union: Union,
    _enum: Enum,
    _struct: Struct,

    const Func = struct {
        name: zstr,
        params: [] Var,
        ret: [] Dtype,
        body: ExprSegment,
    };

    const Val = @compileError("Unimplemented");
    const Union = @compileError("Unimplemented");
    const Enum = @compileError("Unimplemented");
    const Struct = @compileError("Unimplemented");
};

const ExprSegment = struct {
    vars: [] Var,
    exprs: [] Expr,
};

const Expr = union (enum) {
    simple: Simple,
    block: Block,
    _if: If,
    _while: While,
    _for: For,
    _switch: Switch,

    const Simple = struct {
        root: Exprnode,
    };

    const Block = @compileError("Unimplemented");
    const If = @compileError("Unimplemented");
    const For = @compileError("Unimplemented");
    const While = @compileError("Unimplemented");
    const Switch = @compileError("Unimplemented");
};

const ListNode = DLL(Exprnode).Node;

pub fn ParseProgram(alloc: std.mem.Allocator, file: *Str) !Program {
    var prog = Program {.name = "", .decls = undefined};
    var decls = Vec(TLDecl).init(alloc);
    errdefer decls.deinit();
    while (try ParseDecl(alloc, file)) |decl| decls.append(decl);
    prog.decls = decls.toOwnedSlice();
    return prog;
}

pub fn ParseDecl(alloc: std.mem.Allocator, file: *Str) !?TLDecl {
    if (try ParseFunction(alloc, file)) |func| {
        return TLDecl {._func = func};
    } else if (try ParseTLValue(alloc, file)) |val| {
        return TLDecl {._val = val};
    } else if (try ParseUnion(alloc, file)) |uni| {
        return TLDecl {._union = uni};
    } else if (try ParseEnum(alloc, file)) |enu| {
        return TLDecl {._enum = enu};
    } else if (try ParseStruct(alloc, file)) |strc| {
        return TLDecl {._struct = strc};
    } else {
        return null;
    }
}

//Can either return a error, which means unrecoverable failure, a null, meaning can't parse but safe to keep compiling, or a function.
pub fn ParseFunction(alloc: std.mem.Allocator, file: *Str) !?TLDecl.Func {
    file.PopAllFront(strs.IsWS);
    if (!file.CanPopFront()) return null; //If EOF, return null to signal a safe failure to parse

    const ret = try ParseTupleType(alloc, file);
    const name = try ParseIdent(allocs, file);
    try ExpectToken(file, ._left_paren);
    var argsvec = Vec(Arg).init(alloc);
    while (try ParseArg(alloc, file)) |arg| argsvec.append(arg);
    try ExpectToken(file, ._right_paren);
    const body = ParseExprSegment(alloc, file, ArgsToVars(argsvec));
    return TLDecl.Func{.name = name, .params = argsvec.toOwnedSlice(), .ret = ret, .body = body};
}

fn ParseTupleType(alloc: std.mem.Allocator, file: *Str) ![]Dtype {
    var dtypes = Vec(Dtype).init(alloc);
    errdefer dtypes.deinit();
    if (QueryToken(file, ._left_paren)){
        while (ParseType(alloc, file)) |dtype| {
            try dtypes.append(dtype);
            if (QueryToken(file, ._right_paren)) break;
            _ = QueryToken(file, ._comma);
        } else |err| return err;
    } else {
        try dtypes.append(try ParseType(alloc, file));
    }
    return dtypes.toOwnedSlice();
}

const ParseTLValue = @compileError("Unimplemented");
const ParseUnion = @compileError("Unimplemented");
const ParseEnum = @compileError("Unimplemented");
const ParseStruct = @compileError("Unimplemented");

fn TreeifyExpr(alloc: std.mem.Allocator, tkns: Vec(Token)) !Exprnode {
    _ = alloc;
    _ = tkns;
}

fn WrapTkns(alloc: std.mem.Allocator, tkns: Vec(Token)) !DLL(Exprnode) {
    var wrapped = DLL(Exprnode){};
    for (tkns.items) |token| {
        const wrapptr = try alloc.create(ListNode);
        const exprwrap = Exprnode{
            .children = Vec(Exprnode).init(alloc),
            .dtype = undefined,
            .textref = token.textref,
            .token = token,
            .value = null,
        };
        wrapptr.* = ListNode{ .data = exprwrap };
        wrapped.append(wrapptr);
    }
    return wrapped;
}

fn DeinitList(alloc: std.mem.Allocator, itype: type, ary: DLL(itype)) void {
    var qnode = ary.first;
    while (qnode) |nodeptr| {
        qnode = nodeptr.next;
        alloc.destroy(nodeptr);
    }
}
fn RecursiveDeinitList(alloc: std.mem.Allocator, itype: type, ary: DLL(itype)) void {
    var qnode = ary.first;
    while (qnode) |nodeptr| {
        qnode = nodeptr.next;
        nodeptr.data.deinit();
        alloc.destroy(nodeptr);
    }
}

fn ExpectToken(expr: *Str, tkn: TokenType) !void {
    const copy = expr.*;
    errdefer expr.* = copy;
    
    const got = try Tknz.ReadToken(expr, false);
    if (got != tkn) {
        expr.Error("Expected token: {}, got token: {}\n", .{@tagName(tkn), @tagName(got)});
        return error.Got_Incorrect_Token;
    }
}

///Does not consume the token on a false
fn QueryToken(expr: *Str, tkn: TokenType) !bool {
    const copy = expr.*;
    const got = try Tknz.ReadToken(expr, false);
    if (got == tkn) return true;
    expr.* = copy;  //Restore on false
    return false;
}

fn AtmpReduce(token: TokenType, todirection: enum {LR, RL}) !void {
    const toright = todirection == .LR;
    if (token.IsOperand()) return error.Cannot_Reduce_Operand;
    if (token.IsStructural() and toright and !token.CanCapRight()) return error.Symbol_Cannot_Reduce_Right;
    if (token.IsStructural() and !toright and !token.CanCapLeft()) return error.Symbol_Cannot_Reduce_Left;
    if (token.IsKWord()) return error.Cannot_Reduce_Keyword;
}

fn ReduceCenter(list: *DLL(Exprnode), node: *ListNode) !void {
    const left = node.prev orelse return error.Reduction_of_Expression_Boundary;
    const right = node.next orelse return error.Reduction_of_Expression_Boundary;
    
    AtmpReduce(left.data.token.ttype, .LR) catch |err| {
        left.data.token.textref.Error("Reduction Failure `{e}`", .{err});
        return err;
    };
    AtmpReduce(right.data.token.ttype, .RL) catch |err| {
        right.data.token.textref.Error("Reduction Failure `{e}`", .{err});
        return err;
    };
    
    list.remove(left);
    list.remove(right);
    try node.data.children.append(left.data);
    try node.data.children.append(right.data);
    node.data.textref.start = left.data.textref.start;
    node.data.textref.end = right.data.textref.end;
}

fn ReduceLeft(list: *DLL(Exprnode), node: *ListNode) !void {
    const right = node.next orelse return error.Reduction_of_Expression_Boundary;
    AtmpReduce(right.data.token.ttype, .RL) catch |err| {
        right.data.token.textref.Error("Reduction Failure `{e}`", .{err});
        return err;
    };
    list.remove(right);
    try node.data.children.append(right.data);
    node.data.textref.end = right.data.textref.end;
}

test "Wrapping" {
    const expect = std.testing.expect;

    const alloc = std.testing.allocator;
    var tokens: Vec(Token) = undefined;
    var file: Str = Str.FromSlice("");

    file = Str.FromSlice("a + b;");
    tokens = try Tknz.ExprToTokens(alloc, &file);
    const wrapped = try WrapTkns(alloc, tokens);
    try expect(wrapped.first.?.data.token.ttype == ._ident);
    try expect(wrapped.first.?.next.?.data.token.ttype == ._add);
    try expect(wrapped.first.?.next.?.next.?.data.token.ttype == ._ident);
    try expect(wrapped.first.?.next.?.next.?.next.?.data.token.ttype == ._semicolon);
    tokens.deinit();
    DeinitList(alloc, Exprnode, wrapped);
}

test "Basic Folding" {
    const expect = std.testing.expect;
    const expectErr = std.testing.expectError;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var tokens: Vec(Token) = undefined;
    var file: Str = Str.FromSlice("");
    var wrapped: DLL(Exprnode) = undefined;
    var err: anyerror!void = undefined;


    file = Str.FromSlice("a + b;");
    tokens = try Tknz.ExprToTokens(alloc, &file);
    wrapped = try WrapTkns(alloc, tokens);

    try ReduceCenter(&wrapped, wrapped.first.?.next.?);
    try expect(wrapped.first.?.data.token.ttype == ._add);
    try expect(wrapped.first.?.data.children.items[0].token.ttype == ._ident);
    try expect(wrapped.first.?.data.children.items[1].token.ttype == ._ident);
    try expect(wrapped.first.?.next.?.data.token.ttype == ._semicolon);


    file = Str.FromSlice("* b;");
    tokens = try Tknz.ExprToTokens(alloc, &file);
    wrapped = try WrapTkns(alloc, tokens);

    err = ReduceCenter(&wrapped, wrapped.first.?);
    try expectErr(error.Reduction_of_Expression_Boundary, err);


    file = Str.FromSlice("~ b;");
    tokens = try Tknz.ExprToTokens(alloc, &file);
    wrapped = try WrapTkns(alloc, tokens);

    try ReduceLeft(&wrapped, wrapped.first.?);
    try expect(wrapped.first.?.data.token.ttype == ._tilde);
    try expect(wrapped.first.?.data.children.items[0].token.ttype == ._ident);
    try expect(wrapped.first.?.next.?.data.token.ttype == ._semicolon);

    
    file = Str.FromSlice("~)");
    tokens = try Tknz.ExprToTokens(alloc, &file);
    wrapped = try WrapTkns(alloc, tokens);

    err = ReduceLeft(&wrapped, wrapped.first.?);
    try expectErr(error.Reduction_of_Expression_Boundary, err);
}
