const std = @import("std");
const Device = @import("Device.zig");
const Self = @This();

pub const VTable = struct {
    getDevices: *const fn (*anyopaque) anyerror![]const *Device,
    destroy: *const fn (*anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn getDevices(self: *Self) anyerror![]const *Device {
    return self.vtable.getDevices(self.ptr);
}

pub inline fn destroy(self: *Self) void {
    return self.vtable.destroy(self.ptr);
}
