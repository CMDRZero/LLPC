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
    aquisType: AquisType,

    const AquisType = enum {aqConst, aqCopy, aqMut};
};

const ArgType = struct {
    dtype: Dtype,
    aquisType: Arg.AquisType,
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
    const name = try ParseIdent(file);
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

const ParseType = @compileError("Unimplemented");
const ParseArg = @compileError("Unimplemented");
const ParseExprSegment = @compileError("Unimplemented");
const ArgsToVars = @compileError("Unimplemented");

fn ParseIdent(file: *Str) ![]u8 {
    const tkn = try Tknz.ReadToken(file, false);
    return tkn.textref.ToSlice();
}

fn ParseArgType(alloc: std.mem.Allocator, file: *Str) !ArgType {
    var aquisitionType: Arg.AquisType = undefined;
    var tkns = Vec(Token).init(alloc);
    while (true) {
        if (try QueryToken(file, ._comma)) break;
        try tkns.append(try Tknz.ReadToken(file, false));
        file.PopAllFront(strs.IsWS);
    }
    const aquiTkn = tkns.items[tkns.items.len - 1];
    if (aquiTkn.ttype == ._const){
        aquisitionType = .aqConst;
    } else if (aquiTkn.ttype == ._copy){
        aquisitionType = .aqCopy;
    } else if (aquiTkn.ttype == ._mut){
        aquisitionType = .aqMut;
    } else {
        return error.Invalid_Aquisition_Type;
    }
    tkns.shrinkRetainingCapacity(tkns.items.len - 1);

    var innerType: Dtype = try InnerParseType(tkns);
    if (innerType.modqualfs.items.len != 0){
        innerType.modqualfs.items[innerType.modqualfs.items.len - 1] = ._const;
    } else {
        innerType.rootqualf = ._const;
    }
    return ArgType{.dtype =  innerType, .aquisType = aquisitionType};
}

fn InnerParseType(tkns: Vec(Token)) !Dtype {
    const root = try ParseRootType(tkns.items[0]);
    var rootqualf: Dtype.TypeQualf = ._none;
    const State = enum {
        norm, //Undifferentiated type
        l_brack, //We saw a `[`, so could be [], or [k]
        array, //We have [k, so we expect a ]
    };
    var state: State = .norm;
    var mods = Vec(Dtype.TypeMod).init(tkns.allocator);
    var modqualfs = Vec(Dtype.TypeQualf).init(tkns.allocator);
    var arysize: u16 = 0;

    for (tkns.items) |tkn| {
        switch (state) {
            .norm => {
                switch (tkn.ttype) {
                    ._mul => {
                        try mods.append(.pointer);
                        try modqualfs.append(._none);
                    }, ._left_bracket => {
                        state = .l_brack;
                    }, ._q_mark => {
                        try mods.append(.nullable);
                        try modqualfs.append(._none);
                        state = .norm;
                    }, ._const => {
                        if (modqualfs.items.len == 0) { rootqualf = ._const; } 
                        else { modqualfs.items[modqualfs.items.len - 1] = ._const; }
                    }, ._mut => {
                        if (modqualfs.items.len == 0) { rootqualf = ._mut; } 
                        else { modqualfs.items[modqualfs.items.len - 1] = ._mut; }
                    }, else => {},
                }
            }, .l_brack => {
                switch (tkn.ttype) {
                    ._number => {
                        arysize = @intCast(try ComputeInt(tkn.textref));
                        state = .array;
                    }, ._right_bracket => {
                        try mods.append(.slice);
                        try modqualfs.append(._none);
                        state = .norm;
                    }, else => return error.Invalid_Type,
                }
            }, .array => {
                switch (tkn.ttype) {
                    ._right_bracket => {
                        try mods.append(.{ .array = .{.length = arysize} });
                        try modqualfs.append(._none);
                        state = .norm;
                    }, else => return error.Invalid_Type,
                }
            }
        }
    }

    return Dtype{.root = root, .rootqualf = rootqualf, .mods = mods, .modqualfs = modqualfs};

}

fn ParseRootType(tkn: Token) !Dtype.roottype {
    if (tkn.ttype != ._ident) return error.RootType_Isnt_Ident;
    if (try tkn.textref.PeekFront() == 'u'){
        var nstr = tkn.textref.Copy();
        try nstr.PopFront();
        const width = try ParseTypeInt(nstr.ToSlice());
        return Dtype.roottype {.int = .{.signed = false, .width = width}};
    }
    else if (try tkn.textref.PeekFront() == 'i'){
        var nstr = tkn.textref.Copy();
        try nstr.PopFront();
        const width = try ParseTypeInt(nstr.ToSlice());
        return Dtype.roottype {.int = .{.signed = true, .width = width}};
    }
    return error.Failed_To_Parse_Type;
}

fn ComputeInt(str: Str) !u256 {
    return try ComputeBasedInt(str)
    orelse try ComputeDecInt(str);
}

fn ComputeBasedInt(str: Str) !?u256 {
    const slice = str.ToSlice();
    var val: u260 = 0;
    if (slice[0] != '0') return null;

    const base: u8 = switch (slice[1]) {
        'b' => 2,
        'o' => 8,
        'x' => 16,
        else => return null,
    };

    for (slice[2..]) |char| {
        if ('0' <= char and char <= '9' and (char - '0') < base){
            val *= base;
            val += char - '0';
            if (val >= 1 << 256) return error.Int_Too_Large;
        } else if ('a' <= char and char < ('a' + base - 10)){
            val *= base;
            val += char - 'a';
            if (val >= 1 << 256) return error.Int_Too_Large;
        } else if (char == '_') {
        } else {
            return error.Symbol_Invalid_For_Int;
        }
    }
    return @intCast(val);
}

fn ComputeDecInt(str: Str) !u256 {
    var val: u260 = 0;
    for (str.ToSlice()) |char| {
        if ('0' <= char and char <= '9'){
            val *= 10;
            val += char - '0';
            if (val >= 1 << 256) return error.Int_Too_Large;
        } else if (char == '_') {
        } else {
            return error.Symbol_Invalid_For_Int;
        }
    }
    return @intCast(val);
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
    expr.PopAllFront(strs.IsWS);
    if (got != tkn) {
        expr.Error("Expected token: {}, got token: {}\n", .{@tagName(tkn), @tagName(got)});
        return error.Got_Incorrect_Token;
    }
}

///Does not consume the token on a false
fn QueryToken(expr: *Str, tkn: TokenType) !bool {
    const copy = expr.*;
    const got = try Tknz.ReadToken(expr, false);
    expr.PopAllFront(strs.IsWS);
    if (got.ttype == tkn) return true;
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
        left.data.token.textref.Error("Reduction Failure `{any}`", .{err});
        return err;
    };
    AtmpReduce(right.data.token.ttype, .RL) catch |err| {
        right.data.token.textref.Error("Reduction Failure `{any}`", .{err});
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
        right.data.token.textref.Error("Reduction Failure `{any}`", .{err});
        return err;
    };
    list.remove(right);
    try node.data.children.append(right.data);
    node.data.textref.end = right.data.textref.end;
}

test "Compute Ints" {
    const expect = std.testing.expect;
    const expectErr = std.testing.expectError;

    const big = Str.FromSlice("115792089237316195423570985008687907853269984665640564039457584007913129639936");
    try expectErr(error.Int_Too_Large, ComputeDecInt(big));

    const bighex = Str.FromSlice("0x10000000000000000000000000000000000000000000000000000000000000000");
    try expectErr(error.Int_Too_Large, ComputeBasedInt(bighex));

    try expect(try ComputeBasedInt(Str.FromSlice("0b111")) == 7);
    try expect(try ComputeDecInt(Str.FromSlice("123")) == 123);

    try expect(try ComputeInt(Str.FromSlice("0o101")) == 0o101);
    try expect(try ComputeInt(Str.FromSlice("0b1101")) == 0b1101);
    try expect(try ComputeInt(Str.FromSlice("0234")) == 234);
}

test "Parse Type" {
    const expect = std.testing.expect;
    const expectEql = std.testing.expectEqual;
    //const expectErr = std.testing.expectError;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;
        var stream = Str.FromSlice("u8 * copy x");

        const arg = try ParseArgType(alloc, &stream);
        try expect(arg.aquisType == .aqCopy);
        try expectEql(arg.dtype.root, Dtype.roottype{.int = .{.width = 8, .signed = false}});
        try expect(arg.dtype.rootqualf == ._none);
        try expect(arg.dtype.mods.items.len == 1);
        try expect(arg.dtype.mods.items[0] == .pointer);
        try expect(arg.dtype.modqualfs.items.len == 1);
        try expect(arg.dtype.modqualfs.items[0] == ._none);
    }

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;
        var stream = Str.FromSlice("u176 const*const[183]mut? copy x"); // u176 const, * const, [183] mut, ? none, copy

        const arg = try ParseArgType(alloc, &stream);
        try expectEql(Dtype.roottype{.int = .{.width = 176, .signed = false}}, arg.dtype.root);
        try expectEql(._const, arg.dtype.rootqualf);
        
        try expectEql(3, arg.dtype.modqualfs.items.len);
        try expectEql(3, arg.dtype.mods.items.len);
        
        try expectEql(.pointer, arg.dtype.mods.items[0]);
        try expectEql(._const, arg.dtype.modqualfs.items[0]);

        try expectEql(Dtype.TypeMod{.array = .{.length = 183}}, arg.dtype.mods.items[1]);
        try expectEql(._mut, arg.dtype.modqualfs.items[1]);

        try expectEql(.nullable, arg.dtype.mods.items[2]);
        try expectEql(._none, arg.dtype.modqualfs.items[2]);

        try expect(arg.aquisType == .aqCopy);
    }
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
