const std = @import("std");
const Vec = std.ArrayList;

pub fn ScopeStack(comptime T: type) type {
    return struct {
        const Self = @This();
        items: []T,
        capacity: usize,
        alloc: std.mem.Allocator,

        pub fn Init(alloc: std.mem.Allocator) Self {
            return Self{
                .alloc = alloc,
                .capacity = 0,
                .items = &[_]T{},
            };
        }

        fn growCapacity(current: usize, minimum: usize) usize {
            var new = current;
            while (true) {
                new +|= new / 2 + 8;
                if (new >= minimum)
                    return new;
            }
        }

        fn Fit(self: *Self, new_capacity: usize) void {
            if (self.capacity >= new_capacity) return;

            const better_capacity = growCapacity(self.capacity, new_capacity);
            return self.ensureTotalCapacityPrecise(better_capacity);
        }

        pub fn addOne(self: *Self) *T {
            // This can never overflow because `self.items` can never occupy the whole address space
            const newlen = self.items.len + 1;
            try self.Fit(newlen);
            return self.addOneAssumeCapacity();
        }

        pub fn append(self: *Self, item: T) std.mem.Allocator.Error!void {
            const new_item_ptr = try self.addOne();
            new_item_ptr.* = item;
        }

        pub fn ensureTotalCapacityPrecise(self: *Self, new_capacity: usize) std.mem.Allocator.Error!void {
            // Here we avoid copying allocated but unused bytes by
            // attempting a resize in place, and falling back to allocating
            // a new buffer and doing our own copy. With a realloc() call,
            // the allocator implementation would pointlessly copy our
            // extra capacity.
            const old_memory = self.allocatedSlice();
            if (self.allocator.resize(old_memory, new_capacity)) {
                self.capacity = new_capacity;
            } else {
                const new_memory = try self.allocator.alignedAlloc(T, alignment, new_capacity);
                @memcpy(new_memory[0..self.items.len], self.items);
                self.allocator.free(old_memory);
                self.items.ptr = new_memory.ptr;
                self.capacity = new_memory.len;
            }
        }
    };
}
