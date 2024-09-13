const std = @import("std");
const Vec = std.ArrayList;
const DLL = std.DoublyLinkedList;

const strs = @import("strings.zig");
const Str = strs.Str;

const ShowErrorAtPoint = @import("errors.zig").ShowErrorAtPoint;

const tokenizer = @import("tokenizer.zig");
const Token = tokenizer.Token;

pub const AstNode = struct {
    token: Token,
    children: std.ArrayList(*AstNode) = {},
};

const Operand = struct {
    symbol: []const u8,
    precedence: u8,
    assoc: Associativity,

    const Associativity = enum {
        LR,
        RL,
    };

    const 
};

const ListNode = DLL(AstNode).Node;

fn ParseExprToAST(expr: *Str, tokenbuffer: *Vec(Token)) !AstNode {
    tokenizer.ExprToTokens(expr, tokenbuffer);
    var flattkns = DLL(Token){};
    for (tokenbuffer.items) |tkn| {
        const wrappedNode = AstNode {.token = tkn};
        flattkns.append(ListNode{.data = wrappedNode});
    }


}