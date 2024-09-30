const std = @import("std");
const Vec = std.ArrayList;
const DLL = std.DoublyLinkedList;

const strs = @import("strings.zig");
const Str = strs.Str;

const ShowErrorAtPoint = @import("errors.zig").ShowErrorAtPoint;
const DPrint = @import("std").debug.print;

const tokenizer = @import("tokenizer.zig");
const Token = tokenizer.Token;

pub const AstNode = struct {
    token: Token,
    qOp: ?Operand = null,
    children: std.ArrayList(*AstNode),

    pub fn Error(self: AstNode, comptime fmt: []const u8, args: anytype) void {
        var fakeStr: Str = self.token.data;
        if (self.children.items.len > 0) {
            fakeStr.start = self.children.items[0].token.data.start;
            fakeStr.end = self.children.items[self.children.items.len - 1].token.data.end;
        }

        fakeStr.Error(fmt, args);
    }
};

const Operand = struct {
    symbol: []const u8,
    precedence: u8,
    assoc: Associativity,
    reduce: Reduction,

    fn new(symbol: []const u8, prec: u8, assoc: Associativity, reduce: Reduction) Operand {
        return .{ .symbol = symbol, .precedence = prec, .assoc = assoc, .reduce = reduce };
    }

    const Associativity = enum {
        LR,
        RL,
    };

    const Reduction = enum {
        infix,
        prefix,
        postfix,
    };
};

const explicitOperands = [_]Operand{
    Operand.new(".", 0, .LR, .infix),
    Operand.new(".*", 0, .LR, .postfix),
    Operand.new(".&", 0, .LR, .postfix),

    Operand.new("+", 1, .RL, .prefix),
    Operand.new("-", 1, .RL, .prefix),
    Operand.new("!", 1, .RL, .prefix),
    Operand.new("~", 1, .RL, .prefix),

    Operand.new("*", 2, .LR, .infix),
    Operand.new("/", 2, .LR, .infix),
    Operand.new("%", 2, .LR, .infix),
    Operand.new("<<", 2, .LR, .infix),
    Operand.new("<<<", 2, .LR, .infix),
    Operand.new(">>", 2, .LR, .infix),
    Operand.new(">>>", 2, .LR, .infix),

    Operand.new("+", 3, .LR, .infix),
    Operand.new("-", 3, .LR, .infix),

    Operand.new("&", 4, .LR, .infix),

    Operand.new("^", 5, .LR, .infix),

    Operand.new("|", 6, .LR, .infix),

    Operand.new("<", 7, .LR, .infix),
    Operand.new("<=", 7, .LR, .infix),
    Operand.new("==", 7, .LR, .infix),
    Operand.new(">=", 7, .LR, .infix),
    Operand.new(">", 7, .LR, .infix),
    Operand.new("!=", 7, .LR, .infix),

    Operand.new("and", 8, .LR, .infix),

    Operand.new("or", 9, .LR, .infix),

    Operand.new("=", 10, .RL, .infix),
    Operand.new("+=", 10, .RL, .infix),
    Operand.new("-=", 10, .RL, .infix),
    Operand.new("*=", 10, .RL, .infix),
    Operand.new("/=", 10, .RL, .infix),
    Operand.new("%=", 10, .RL, .infix),
    Operand.new("<<=", 10, .RL, .infix),
    Operand.new("<<<=", 10, .RL, .infix),
    Operand.new(">>=", 10, .RL, .infix),
    Operand.new(">>>=", 10, .RL, .infix),
    Operand.new("&=", 10, .RL, .infix),
    Operand.new("^=", 10, .RL, .infix),
    Operand.new("|=", 10, .RL, .infix),
};

pub const maxprec = b: {
    var maxind: u8 = 0;
    var prevassoc = explicitOperands[0].assoc;
    for (explicitOperands) |op| {
        if (op.precedence == maxind + 1) {
            maxind += 1;
            prevassoc = op.assoc;
        } else if (op.precedence > maxind + 1) {
            const msg = std.fmt.comptimePrint("Operand `{s}` has precidence `{}`, which is greater than previous max of `{}`\nOperands must have sequential precidences\n", .{ op.symbol, op.precedence, maxind });
            @compileError(msg);
        } else if (op.precedence < maxind) {
            const msg = std.fmt.comptimePrint("Operand `{s}` has precidence `{}`, which is less previous precidence of `{}`\nOperands must have sequential precidences\n", .{ op.symbol, op.precedence, maxind });
            @compileError(msg);
        } else if (prevassoc != op.assoc) {
            const msg = std.fmt.comptimePrint("Operand `{s}` has associativity `{}`, which is different than the previous operands `{}`\nOperands of the same precidence must have the same associativity\n", .{ op.symbol, op.assoc, prevassoc });
            @compileError(msg);
        }
    }

    break :b maxind;
};

const ListNode = DLL(AstNode).Node;
const OpFrame = struct {
    slots: [maxprec+1] Vec(*ListNode),
    opener: AstNode = undefined,
};

//  * * * * * * * * * * * * * * * * * * * *          * * * * * * * * * * * * * * * * * * * *  
// * * * * * * * * * * * * * * * * * * * * * Funcs  * * * * * * * * * * * * * * * * * * * * * 
//  * * * * * * * * * * * * * * * * * * * *          * * * * * * * * * * * * * * * * * * * * 

pub fn ParseExprToAST(expr: *Str, tokenbuffer: *Vec(Token), allocator: std.mem.Allocator) !AstNode {
    try tokenizer.ExprToTokens(expr, tokenbuffer);
    var flattkns = DLL(AstNode){};
    for (tokenbuffer.items) |tkn| {
        const children = Vec(*AstNode).init(allocator);
        const wrappedNode = AstNode{ .token = tkn, .children = children };
        const newnode = try allocator.create(ListNode);
        newnode.* = ListNode{ .data = wrappedNode };
        flattkns.append(newnode);
    }

    //@compileError("Add nullwidth operands like func-call, index, typecast, and typeinst");
    
    //@compileError("Add Order of Op resolution here");
    var framebuffer = Vec(OpFrame).init(allocator);
    DPrint("Length of tkns is {}\n", .{flattkns.len});
    var qcurrnode: ?*ListNode = flattkns.first;
    while (qcurrnode) |currnodeptr| : (qcurrnode = currnodeptr.next){
        DPrint("CurrNode is {}\n", .{currnodeptr.data.token});
    }
    try ResolveOrderOfOps(&flattkns, &framebuffer);

    if (flattkns.len > 1) {
        flattkns.first.?.next.?.data.token.data.Error("Token does not resolve\n", .{});
        flattkns.first.?.data.Error("Expression ends here: \n", .{});
        return error.Unresolved_Tokens;
    }

    return flattkns.first.?.data;
}

pub fn ResolveOrderOfOps(flatnodes: *DLL(AstNode), OFStack: *Vec(OpFrame)) !void {
    try OFStack.append(OpFrame{.slots = .{Vec(*ListNode).init(OFStack.allocator)} ** (1 + maxprec)});
    var orderedOps = Vec(*ListNode).init(OFStack.allocator);
    
    var qcurrnode: ?*ListNode = flatnodes.first;
    while (qcurrnode) |currnodeptr| : (qcurrnode = currnodeptr.next){
        var currnode = currnodeptr.*;
        const nodestr = currnode.data.token.data;
        const nodetype = currnode.data.token.dtype;

        var TStack = OFStack.items[OFStack.items.len - 1];

        DPrint("currnode: {} has type: {}\n", .{currnode.data.token, nodetype});

        switch (nodetype) {
            .bin_op, .un_op => {
                for (explicitOperands) |op| {
                    if(tokenizer.StrEq(nodestr, op.symbol)) {
                        const prec = op.precedence;
                        currnode.data.qOp = op;
                        try TStack.slots[prec].append(currnodeptr);
                        DPrint("Found operand\n", .{});
                        break;
                    }
                } else {
                    nodestr.Error("Operand cannot be looked up in precidence table\n", .{});
                    return error.Operand_Missing_Precidence;
                }
                DPrint("Resolved operand\n", .{});
            },
            .fn_call, .struct_inst, .type_cast => {
                @panic("Unimplemented code path: nullwidth operands");
            },
            .ident, .keyword, .num => {
                _ = 0;
            },
            .structural => {
                const tknstr = currnode.data.token.data;
                if( tokenizer.StrEq(tknstr, ";")){
                    continue;
                } else if (tokenizer.StrEq(tknstr, "(")) {

                } else {
                    unreachable;
                }
                @panic("Unimplemented code path: structurals");
            },
        }
    } else {
        DPrint("Did not break\n", .{});
    }
    DPrint("End of loop\n", .{});

    if(OFStack.items.len > 1) {
        OFStack.items[1].opener.Error("Unclosed frame\n", .{});
    }
    
    const CFrame = OFStack.items[0];
    for (0..maxprec + 1 ) |prec| {
        const cprec = CFrame.slots[prec];
        if (cprec.items.len == 0) continue;
        const dir: Operand.Associativity = cprec.items[0].data.qOp.?.assoc;
        if (dir == .LR){
            var idx: usize = 0;
            while (idx < orderedOps.items.len) : (idx += 1){
                try orderedOps.append(cprec.items[idx]);
            }
        } else if (dir == .RL) {
            var idx: usize = orderedOps.items.len;
            while (idx > 0){
                idx -= 1;
                try orderedOps.append(cprec.items[idx]);
            }
        } else unreachable;
    }

    if(0 == @intFromPtr(@as(*allowzero u64 , @ptrFromInt(@as(u64, 0))))){ @panic("Didnt expect to get this far"); }
}
