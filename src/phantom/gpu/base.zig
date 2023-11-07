const std = @import("std");
const Device = @import("device.zig");
const Base = @This();

pub const VTable = struct {
    enumerate: *const fn (*anyopaque) anyerror!std.ArrayList(*Device),
    dupe: *const fn (*anyopaque) anyerror!*Base,
    deinit: ?*const fn (*anyopaque) void = null,
};

vtable: *const VTable,
ptr: *anyopaque,

pub inline fn enumerate(self: *Base) !std.ArrayList(*Device) {
    return self.vtable.enumerate(self.ptr);
}

pub inline fn dupe(self: *Base) !*Base {
    return self.vtable.dupe(self.ptr);
}

pub inline fn deinit(self: *Base) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
