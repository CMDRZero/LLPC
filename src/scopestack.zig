const std = @import("std");
const Vec = std.ArrayList;

pub fn ScopeStack(comptime T: type) type {
    return struct {
        const Self = @This();
        vec: Vec(T),
        stacks: Vec(usize),

        pub fn NewFrame(self: *Self) !void {
            try self.stacks.append(self.vec.items.len);
        }

        pub fn PopFrame(self: *Self) !void {
            try self.vec.resize(self.stacks.pop());
        }
        pub fn Init(alloc: std.mem.Allocator) Self {
            return Self{
                .vec = Vec(T).init(alloc),
                .stacks = Vec(usize).init(alloc),
            };
        }
        pub fn append(self: *Self, item: T) !void {
            try self.vec.append(item);
        }
    };
}
