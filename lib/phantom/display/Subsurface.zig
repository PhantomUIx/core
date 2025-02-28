const std = @import("std");
const graphics = @import("../graphics.zig");
const math = @import("../math.zig");
const Surface = @import("Surface.zig");
const Self = @This();

pub const VTable = struct {
    getPosition: *const fn (*anyopaque) math.Vec2(usize),
    getSize: *const fn (*anyopaque) math.Vec2(usize),
    getChildren: *const fn (*anyopaque) []const Surface,
    destroy: *const fn (*anyopaque) void,
};

pub const surface_vtable: Surface.VTable = .{
    .getSize = vtable_getSize,
    .getChildren = vtable_getChildren,
    .destroy = vtable_destroy,
};

base: Surface,
ptr: *anyopaque,
vtable: *const VTable,

pub inline fn init(self: *Self, ptr: *anyopaque, vtable: *const VTable) Self {
    return .{
        .base = .{
            .ptr = self,
            .vtable = &surface_vtable,
        },
        .ptr = ptr,
        .vtable = vtable,
    };
}

pub inline fn getPosition(self: *Self) math.Vec2(usize) {
    return self.vtable.getPosition(self.ptr);
}

pub inline fn getSize(self: *Self) math.Vec2(usize) {
    return self.vtable.getSize(self.ptr);
}

pub inline fn getChildren(self: *Self) []const Surface {
    return self.vtable.getChildren(self.ptr);
}

pub inline fn destroy(self: *Self) void {
    return self.vtable.destroy(self.ptr);
}

fn vtable_getSize(ctx: *anyopaque) math.Vec2(usize) {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.getSize();
}

fn vtable_getPosition(ctx: *anyopaque) math.Vec2(usize) {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.getPosition();
}

fn vtable_getChildren(ctx: *anyopaque) []const Surface {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.getChildren();
}

fn vtable_destroy(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.destroy();
}
