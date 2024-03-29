const std = @import("std");
const Base = @This();

pub const VTable = struct {
    deinit: ?*const fn (*anyopaque) void = null,
};

vtable: *const VTable,
ptr: *anyopaque,

pub inline fn deinit(self: *const Base) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
