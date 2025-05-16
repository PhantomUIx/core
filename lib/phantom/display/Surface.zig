const std = @import("std");
const graphics = @import("../graphics.zig");
const math = @import("../math.zig");
const Self = @This();

pub const VTable = struct {
    getSize: *const fn (*anyopaque) math.Vec2(usize),
    getChildren: *const fn (*anyopaque) []const Self,
    destroy: *const fn (*anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn getSize(self: *Self) math.Vec2(usize) {
    return self.vtable.getSize(self.ptr);
}

pub inline fn getChildren(self: *Self) []const Self {
    return self.vtable.getChildren(self.ptr);
}

pub inline fn destroy(self: *Self) void {
    return self.vtable.destroy(self.ptr);
}
