const std = @import("std");
const Vec = std.ArrayList;

pub const ID = u32;

pub const Trie = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    maxID: ID = 0,
    root: TrieNode = .{.next = .{.branch = ([_]?*TrieNode{null})**256}},
    table: Vec([]const u8),

    pub fn Init(alloc: std.mem.Allocator) Trie {
        return Trie{
            .alloc = alloc,
            .table = Vec([]const u8).init(alloc),
        };
    }

    pub fn Register(self: *Self, string: []const u8) !ID {
        var curr: *TrieNode = &self.root;
        for (string) |char| {
            switch (curr.next) {
                .branch => |*children| {
                    var child = children[char];
                    if (child == null) {
                        child = try self.alloc.create(TrieNode);
                        children[char] = child;
                        child.?.next = .{.branch = ([_]?*TrieNode{null})**256};
                    }
                    curr = child.?;
                }, .leaf => unreachable, 
            }
        }
        if (curr.next == .leaf) unreachable;
        if (curr.next.branch[0] != null) return error.Duplicate;
        curr.next.branch[0] = try self.alloc.create(TrieNode);
        curr.next.branch[0].?.next = .{ .leaf = self.maxID };
        defer self.maxID += 1;
        try self.table.append(string);
        return self.maxID;
    }

    pub fn Lookup(self: Self, string: [] const u8) ?ID {
        var curr: TrieNode = self.root;
        for (string) |char| {
            switch (curr.next) {
                .branch => |children| curr = (children[char] orelse return null).*, 
                .leaf => unreachable, 
            }
        }
        if (curr.next == .leaf) unreachable;
        curr = (curr.next.branch[0] orelse return null).*;
        if (curr.next == .branch) return null;
        return curr.next.leaf;
    }

    pub fn WriteGet(self: *Self, string: []const u8) !ID {
        return self.Lookup(string) orelse try self.Register(string);
    }
};

const TrieNode = struct {
    next: TrieNext,
};

const TrieNext = union (enum) {
    branch: [256]?*TrieNode,
    leaf: ID,
};

test "Register Names" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var tree = Trie.Init(alloc);
    const xid = try tree.Register("x"[0..]);
    try std.testing.expect(xid == 0);

    var abc = "abc";
    const abcid = try tree.Register(abc[0..]);
    try std.testing.expect(abcid == 1);

    try std.testing.expectError(error.Duplicate, tree.Register(abc[0..]));

    try std.testing.expectEqual(1, tree.Lookup(abc[0..]));

    try std.testing.expect(2 == try tree.Register("a"[0..]));
}