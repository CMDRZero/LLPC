const std = @import("std");
const Vec = std.ArrayList;
const DLL = std.DoublyLinkedList;

const strs = @import("strings.zig");
const Str = strs.Str;
const zstr = []const u8; //Zig String type

const Tkns = @import("tokens.zig");
const TokenType = Tkns.TokenType;
const Tknz = @import("newtokenizer.zig");
const Token = Tknz.Token;
const Parser = @import("parser.zig");
const Exprnode = Parser.Exprnode;

const ListNode = DLL(Exprnode).Node;

const OpFrame = struct {
    const Self = @This();

    slots: [Tkns.NUMPRECS]Vec(ListNode),

    fn Init(alloc: std.mem.Allocator) Self {
        return Self{ .slots = [1]Vec(ListNode){Vec(ListNode).init(alloc)} ** Tkns.NUMPRECS };
    }

    fn Append(self: *Self, item: ListNode) !void {
        self.slots[item.data.token.ttype.GetPrec()].append(item);
    }
};

fn TreeifyExpr(alloc: std.mem.Allocator, tkns: Vec(Token)) !Exprnode {
    const TknList = try WrapTkns(alloc, tkns);
    _ = TknList; // autofix

}

fn OrderedOps(alloc: std.mem.Allocator, tkns: DLL(Exprnode)) !Vec(ListNode) {
    var frames = Vec(OpFrame).init(alloc);
    defer frames.deinit();
    var order = Vec(ListNode).init(alloc);
    frames.append(OpFrame.Init(alloc));

    var qcurrptr = tkns.first;
    while (qcurrptr) |currptr| : (qcurrptr = currptr.next) {
        const ttype = currptr.data.token.ttype;
        if (ttype.IsOperand()) {
            frames.getLast().Append(currptr.*);
        } else if (ttype.IsStructural) {
            if (ttype.CanCapLeft()) {
                const oldFrame = frames.pop();
                for (oldFrame.slots, 0..) |slot, idx| {
                    _ = idx;
                    for (slot.items) |elem| order.append(elem);
                    slot.deinit();
                }
            }
            if (ttype.CanCapRight()) {
                frames.append(OpFrame.Init(alloc));
            }
        }
    }
    const oldFrame = frames.pop();
    for (oldFrame.slots, 0..) |slot, idx| {
        _ = idx;
        for (slot.items) |elem| order.append(elem);
        slot.deinit();
    }
    if (frames.items.len != 0) return error.Unclosed_Frame;
    return order;
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

fn AtmpReduce(token: TokenType, todirection: enum { LR, RL }) !void {
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
