const std = @import("std");
const Allocator = std.mem.Allocator;
const Self = @This();

pub const DisposeFn = *const fn (*State, Allocator) void;

pub const State = struct {
    value: []u8,
    disposeFn: ?DisposeFn,
    unused: bool,
    needsFree: bool,

    pub fn dispose(self: *State, alloc: Allocator) void {
        if (self.disposeFn) |f| return f(self, alloc);
    }
};

pub const CleanupMode = enum {
    unused,
    not_unused,
    everything,
};

allocator: Allocator,
map: std.AutoHashMapUnmanaged(usize, State) = .{},

pub fn getState(self: *Self, comptime T: type, id: usize, init: T, disposeFn: ?DisposeFn) !*T {
    if (self.map.get(id)) |state| {
        return @alignCast(@ptrCast(state.value.ptr));
    }

    const buff = try self.allocator.alloc(u8, @sizeOf(T));
    errdefer self.allocator.free(buff);

    const ptr: *T = @alignCast(@ptrCast(buff.ptr));
    ptr.* = init;
    try self.map.put(self.allocator, id, .{
        .value = buff,
        .disposeFn = disposeFn,
        .unused = false,
        .needsFree = false,
    });
    return ptr;
}

pub fn markUnused(self: *Self, id: usize) error{ AlreadyUnused, NotFound }!void {
    const state = self.map.getPtr(id) orelse return error.NotFound;

    if (state.unused) return error.AlreadyUnused;
    state.unused = true;
}

pub fn cleanup(self: *Self, mode: CleanupMode) void {
    var iter = self.map.valueIterator();
    while (iter.next()) |entry| {
        switch (mode) {
            .unused => if (!entry.unused) continue,
            .not_unused => if (entry.unused) continue,
            .everything => {},
        }

        entry.dispose(self.allocator);
        entry.needsFree = true;
    }
}

pub fn collectGarbage(self: *Self) void {
    var iter = self.map.iterator();
    while (iter.next()) |entry| {
        if (!entry.value_ptr.needsFree) continue;

        self.allocator.free(entry.value_ptr.value);
        self.map.removeByPtr(entry.key_ptr);
    }
}

pub fn destroy(self: *Self) void {
    self.cleanup(.everything);
    self.collectGarbage();
}
