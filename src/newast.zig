const std = @import("std");
const Vec = std.ArrayList;
const DLL = std.DoublyLinkedList;

const strs = @import("strings.zig");
const Str = strs.Str;
const zstr = [] const u8;   //Zig String type

const Tkns = @import("tokens.zig");
const TokenType = Tkns.TokenType;
const Tknz = @import("newtokenizer.zig");
const Token = Tknz.Token;
const Parser = @import("parser.zig");
const Exprnode = Parser.Exprnode;

const ListNode = DLL(Exprnode).Node;

const Assoc = enum {LR, RL};
const assocs = [Tkns.NUMPRECS] Assoc {
    .LR,
    .RL,
    .LR,
    .LR,
    .LR,
    .LR,
    .LR,
    .LR,
    .LR,
    .LR,
    .RL,
};

const OpFrame = struct {
    const Self = @This();

    slots: [Tkns.NUMPRECS] Vec(*ListNode),

    fn Init(alloc: std.mem.Allocator) Self {
        return Self{.slots = [1]Vec(*ListNode){Vec(*ListNode).init(alloc)} ** Tkns.NUMPRECS};
    }

    fn Append(self: *Self, item: *ListNode) !void {
        try self.slots[item.data.token.ttype.GetPrec()].append(item);
    }
};

pub fn TreeifyExpr(alloc: std.mem.Allocator, tkns: []Token) !Exprnode {
    var TknList = try WrapTkns(alloc, tkns);
    const order = try OrderedOps(alloc, TknList);
    for (order.items) |opptr| {
        switch (opptr.data.token.ttype.GetInvokeType()){
            .binary => try ReduceCenter(&TknList, opptr),
            .unary_right => try ReduceLeft(&TknList, opptr),
            .multi_arg => try ReduceMultiArg(alloc, &TknList, opptr),
        }
        
    }
    if (TknList.first.?.next) |nex| if (nex.data.token.ttype != ._semicolon){
        var left = nex.data;
        while (left.children.items.len > 1) {
            left = left.children.items[0];
            //left.textref.Error("`{s}`\n", .{@tagName(left.token.ttype)});
        }
        nex.data.textref.Error("Did not reduce, first token has type `{s}`\n", .{@tagName(left.token.ttype)});
        TknList.first.?.data.textref.Error("First token was\n", .{});
        return error.Unreduced_Operand;
    };
    return TknList.first.?.data;
    
}

fn PopFrame(frames: *Vec(*OpFrame), order: *Vec(*ListNode)) !void {
    const oldFrame = frames.pop();
    for (oldFrame.slots, 0..) |slot, idx| {
        const assoc = assocs[idx];
        if (assoc == .LR){
            for (slot.items) |elem| {
                //std.debug.print("Pushed {} at prec {}\n", .{elem.data.token.ttype, idx});
                try order.append(elem);
            }
        } else {
            var i = slot.items.len -% 1;
            while (i < slot.items.len) : (i -%= 1) {
                const elem = slot.items[i];
                try order.append(elem);
            }
        }
        slot.deinit();
    }
}

fn OrderedOps(alloc: std.mem.Allocator, tkns: DLL(Exprnode)) !Vec(*ListNode) {
    var frames = Vec(*OpFrame).init(alloc);
    defer frames.deinit();
    var order = Vec(*ListNode).init(alloc);
    var frameptr = try alloc.create(OpFrame);
    frameptr.* = OpFrame.Init(alloc);
    try frames.append(frameptr);
    var dot: bool = false;

    var qcurrptr = tkns.first;
    while (qcurrptr) |currptr| : (qcurrptr = currptr.next) {
        const ttype = currptr.data.token.ttype;
        if (!dot and ttype.IsOperand()){
            try frames.getLast().Append(currptr);
        } else if (ttype.IsStructural()) {
            if (ttype.CanCapLeft()){
                try PopFrame(&frames, &order);
            }
            if (ttype.CanCapRight()){
                frameptr = try alloc.create(OpFrame);
                frameptr.* = OpFrame.Init(alloc);
                try frames.append(frameptr);
            }
        }
        dot = ttype == ._dot;
    }
    try PopFrame(&frames, &order);
    if (frames.items.len != 0) return error.Unclosed_Frame;
    return order;
}

fn WrapTkns(alloc: std.mem.Allocator, tkns: []Token) !DLL(Exprnode) {
    var wrapped = DLL(Exprnode){};
    for (tkns) |token| {
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

fn AtmpReduce(token: TokenType, todirection: enum {LR, RL}) !void {
    const toright = todirection == .LR;
    //if (token.IsOperand()) return error.Cannot_Reduce_Operand;
    if (token.IsStructural() and !toright and !token.CanCapRight()) return error.Symbol_Cannot_Reduce_Right;
    if (token.IsStructural() and toright and !token.CanCapLeft()) return error.Symbol_Cannot_Reduce_Left;
    if (token.IsKWord()) return error.Cannot_Reduce_Keyword;
}

fn RemPop(list: *DLL(Exprnode), node: *ListNode, todirection: enum {LR, RL}) !*ListNode {
    const toright = todirection == .LR;
    const token = node.data.token.ttype;
    if (token.IsStructural() and !toright and !token.CanCapRight()) return error.Symbol_Cannot_Reduce_Left;
    if (token.IsStructural() and toright and !token.CanCapLeft()) return error.Symbol_Cannot_Reduce_Right;
    if (token.IsKWord()) return error.Cannot_Reduce_Keyword;

    if (token.IsStructural() and !toright and token.CanCapRight()) {
        if (node.next) |nex| {
            if (nex.next) |nexnex| {
                if (nexnex.data.token.ttype.Int() != token.Converse()) return error.Parenthesis_Not_Simplified;
                list.remove(node);
                list.remove(nex);
                list.remove(nexnex);
                return nex;
            } else return error.Reduction_of_Expression_Boundary;
        } else return error.Reduction_of_Expression_Boundary;
    } else if (token.IsStructural() and toright and token.CanCapLeft()) {
        if (node.prev) |nex| {
            if (nex.prev) |nexnex| {
                if (nexnex.data.token.ttype.Int() != token.Converse()) return error.Parenthesis_Not_Simplified;
                list.remove(node);
                list.remove(nex);
                list.remove(nexnex);
                return nex;
            } else return error.Reduction_of_Expression_Boundary;
        } else return error.Reduction_of_Expression_Boundary;
    } else {
        list.remove(node);
        return node;
    }
}

fn RemMultiPop(alloc: std.mem.Allocator, list: *DLL(Exprnode), node: *ListNode) !Vec(*ListNode) {
    const token = node.data.token.ttype;
    if (token.IsStructural() and !token.CanCapRight()) return error.Symbol_Cannot_Reduce_Left;
    if (token.IsKWord()) return error.Cannot_Reduce_Keyword;
    const conv = token.Converse();

    var args = Vec(*ListNode).init(alloc);
    var qnode: ?*ListNode = node.next;
    list.remove(node);
    var sep: bool = true;
    var onode = node;
    while (qnode) |cnode| : ({qnode = cnode.next; list.remove(cnode);}){
        onode = cnode;
        const ttype = cnode.data.token.ttype;
        if (ttype.Int() == conv) break;
        if (ttype == ._comma) {
            sep = true;
        } else if (sep) {
            try args.append(cnode);
        }
        //onode.data.textref.Error("Expected: `{s}`\n", .{@tagName(@as(TokenType, @enumFromInt(conv)))});
    } else {
        onode.data.textref.Error("Expected: `{s}`\n", .{@tagName(@as(TokenType, @enumFromInt(conv)))});
        return error.Reduction_of_Expression_Boundary;
    }
    list.remove(onode);
    return args;
}

fn ReduceMultiArg(alloc: std.mem.Allocator, list: *DLL(Exprnode), node: *ListNode) !void {
    var left = node.prev orelse return error.Reduction_of_Expression_Boundary;
    var right = node.next orelse return error.Reduction_of_Expression_Boundary;

    left = RemPop(list, left, .LR) catch |err| {
        left.data.token.textref.Error("Reduction Failure `{any}`, cannot reduce right\n", .{err});
        return err;
    };
    const rights = RemMultiPop(alloc, list, right) catch |err| {
        right.data.token.textref.Error("Reduction Failure `{any}`, cannot reduce left\n", .{err});
        return err;
    };
    
    try node.data.children.append(left.data);
    for (rights.items) |r| try node.data.children.append(r.data);
    node.data.textref.start = left.data.textref.start;
    node.data.textref.end = right.data.textref.end;
}

fn ReduceCenter(list: *DLL(Exprnode), node: *ListNode) !void {
    var left = node.prev orelse return error.Reduction_of_Expression_Boundary;
    var right = node.next orelse return error.Reduction_of_Expression_Boundary;

    left = RemPop(list, left, .LR) catch |err| {
        left.data.token.textref.Error("Reduction Failure `{any}`, cannot reduce right\n", .{err});
        return err;
    };
    right = RemPop(list, right, .RL) catch |err| {
        right.data.token.textref.Error("Reduction Failure `{any}`, cannot reduce left\n", .{err});
        return err;
    };
    
    try node.data.children.append(left.data);
    try node.data.children.append(right.data);
    node.data.textref.start = left.data.textref.start;
    node.data.textref.end = right.data.textref.end;
}

fn ReduceLeft(list: *DLL(Exprnode), node: *ListNode) !void {
    var right = node.next orelse return error.Reduction_of_Expression_Boundary;
    right = RemPop(list, right, .RL) catch |err| {
        right.data.token.textref.Error("Reduction Failure `{any}`", .{err});
        return err;
    };
    try node.data.children.append(right.data);
    node.data.textref.end = right.data.textref.end;
}

fn DisplayTree(root: Exprnode) void {
    std.debug.print("\n{s} `{s}`\n", .{@tagName(root.token.ttype), root.token.textref.ToSlice()});
    if (root.children.items.len == 0) return;
    for (root.children.items[0..root.children.items.len-1]) |child| {
        RecuDispTree(child, false, 1, 0);
    }
    const finchild = root.children.items[root.children.items.len-1];
    RecuDispTree(finchild, true, 0, 0);
}

fn RecuDispTree(root: Exprnode, fin: bool, ind: u256, len: u8) void {
    for (0..len) |x| {
        const bit = 1 == 1 & (ind >> (len-@as(u8, @intCast(x))));
        if (bit) {
            std.debug.print("│   ", .{});
        } else {
            std.debug.print("    ", .{});
        }
    }
    if (fin) {std.debug.print("└── ", .{});} else std.debug.print("├── ", .{});
    std.debug.print("{s} `{s}`\n", .{@tagName(root.token.ttype), root.token.textref.ToSlice()});
    if (root.children.items.len == 0) return;
    for (root.children.items[0..root.children.items.len-1]) |child| {
        RecuDispTree(child, false, ind << 1 | 1, len + 1);
    }
    const finchild = root.children.items[root.children.items.len-1];
    RecuDispTree(finchild, true, ind << 1 | 0, len + 1);
}

test "Wrapping" {
    const expect = std.testing.expect;

    const alloc = std.testing.allocator;
    var tokens: Vec(Token) = undefined;
    var file: Str = Str.FromSlice("");

    file = Str.FromSlice("a + b;");
    tokens = try Tknz.ExprToTokens(alloc, &file);
    const wrapped = try WrapTkns(alloc, tokens.items);
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
    wrapped = try WrapTkns(alloc, tokens.items);

    try ReduceCenter(&wrapped, wrapped.first.?.next.?);
    try expect(wrapped.first.?.data.token.ttype == ._add);
    try expect(wrapped.first.?.data.children.items[0].token.ttype == ._ident);
    try expect(wrapped.first.?.data.children.items[1].token.ttype == ._ident);
    try expect(wrapped.first.?.next.?.data.token.ttype == ._semicolon);


    file = Str.FromSlice("* b;");
    tokens = try Tknz.ExprToTokens(alloc, &file);
    wrapped = try WrapTkns(alloc, tokens.items);

    err = ReduceCenter(&wrapped, wrapped.first.?);
    try expectErr(error.Reduction_of_Expression_Boundary, err);


    file = Str.FromSlice("~ b;");
    tokens = try Tknz.ExprToTokens(alloc, &file);
    wrapped = try WrapTkns(alloc, tokens.items);

    try ReduceLeft(&wrapped, wrapped.first.?);
    try expect(wrapped.first.?.data.token.ttype == ._tilde);
    try expect(wrapped.first.?.data.children.items[0].token.ttype == ._ident);
    try expect(wrapped.first.?.next.?.data.token.ttype == ._semicolon);

    
    file = Str.FromSlice("~)");
    tokens = try Tknz.ExprToTokens(alloc, &file);
    wrapped = try WrapTkns(alloc, tokens.items);

    err = ReduceLeft(&wrapped, wrapped.first.?);
    try expectErr(error.Reduction_of_Expression_Boundary, err);
}

test "Order of Ops" {
    const expectEql = std.testing.expectEqual;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;

        var file = Str.FromSlice("a + b * c;");
        const tokens = try Tknz.ExprToTokens(alloc, &file);
        const wrapped = try WrapTkns(alloc, tokens.items);
        const ops = try OrderedOps(alloc, wrapped);
        try expectEql(2, ops.items.len);
        try expectEql(tokens.items[3].ttype, ops.items[0].data.token.ttype);
        try expectEql(tokens.items[1], ops.items[1].data.token);
    }

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;

        var file = Str.FromSlice("a + b + c;");
        const tokens = try Tknz.ExprToTokens(alloc, &file);
        const wrapped = try WrapTkns(alloc, tokens.items);
        const ops = try OrderedOps(alloc, wrapped);
        try expectEql(2, ops.items.len);
        try expectEql(tokens.items[1], ops.items[0].data.token);
        try expectEql(tokens.items[3], ops.items[1].data.token);
    }

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;

        var file = Str.FromSlice("a = b = c;");
        const tokens = try Tknz.ExprToTokens(alloc, &file);
        const wrapped = try WrapTkns(alloc, tokens.items);
        const ops = try OrderedOps(alloc, wrapped);
        try expectEql(2, ops.items.len);
        try expectEql(tokens.items[3], ops.items[0].data.token);
        try expectEql(tokens.items[1], ops.items[1].data.token);
    }

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;

        var file = Str.FromSlice("(u16)f(x);");
        const tokens = try Tknz.ExprToTokens(alloc, &file);
        const wrapped = try WrapTkns(alloc, tokens.items);
        const ops = try OrderedOps(alloc, wrapped);
        try expectEql(2, ops.items.len);
        try expectEql(tokens.items[5], ops.items[0].data.token);
        try expectEql(tokens.items[3], ops.items[1].data.token);
    }

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;

        var file = Str.FromSlice("2 * -1;");
        const tokens = try Tknz.ExprToTokens(alloc, &file);
        const wrapped = try WrapTkns(alloc, tokens.items);
        const ops = try OrderedOps(alloc, wrapped);
        try expectEql(2, ops.items.len);
        try expectEql(tokens.items[2], ops.items[0].data.token);
        try expectEql(tokens.items[1], ops.items[1].data.token);
    }
}

test "Full Ast" {
    const expectEql = std.testing.expectEqual;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;

        var file = Str.FromSlice("a + b * c;");
        const tokens = try Tknz.ExprToTokens(alloc, &file);
        const tree = try TreeifyExpr(alloc, tokens.items);
        try expectEql(TokenType._add, tree.token.ttype);
        const child0 = tree.children.items[0];
        try expectEql(TokenType._ident, child0.token.ttype);
        const child1 = tree.children.items[1];
        try expectEql(TokenType._mul, child1.token.ttype);
        const child10 = child1.children.items[0];
        const child11 = child1.children.items[0];
        try expectEql(TokenType._ident, child10.token.ttype);
        try expectEql(TokenType._ident, child11.token.ttype);

        //DisplayTree(tree);
    }

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;

        var file = Str.FromSlice("6^3 | h * abc + 3 - f[34](arg1, arg2).test().hello;");
        //var file = Str.FromSlice("6^3 | h * abc.&.* + 3 - f.*[34](arg1, arg2).&.*.test().*.hello;");
        //var file = Str.FromSlice("ary[-idx + off * scale];");
        const tokens = try Tknz.ExprToTokens(alloc, &file);
        const tree = try TreeifyExpr(alloc, tokens.items);
        _ = tree;
        //DisplayTree(tree);
    }

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;

        //var file = Str.FromSlice("6^3 | h * abc + 3 - f[34](arg1, arg2).test().hello;");
        var file = Str.FromSlice("6^3 | h * -abc.&.* + 3 - ~f.*[34](arg1, arg2).&.*.test().*.hello;");
        //var file = Str.FromSlice("ary[-idx + off * scale];");
        const tokens = try Tknz.ExprToTokens(alloc, &file);
        const tree = try TreeifyExpr(alloc, tokens.items);

        _ = tree;
        //DisplayTree(tree);
    }

    {
        strs.forceShowErrors = true;
        defer strs.forceShowErrors = false;

        //var file = Str.FromSlice("6^3 | h * abc + 3 - f[34](arg1, arg2).test().hello;");
        var file = Str.FromSlice("obj = Vec{x:=0, y:=1};");
        //var file = Str.FromSlice("ary[-idx + off * scale];");
        const tokens = try Tknz.ExprToTokens(alloc, &file);
        const tree = try TreeifyExpr(alloc, tokens.items);

        _ = tree;
        //DisplayTree(tree);
    }
}

