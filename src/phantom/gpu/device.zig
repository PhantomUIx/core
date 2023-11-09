const std = @import("std");
const Surface = @import("surface.zig");
const Fb = @import("../painting/fb/base.zig");
const Device = @This();

pub const VTable = struct {
    createSurface: *const fn (*anyopaque, Surface.Info) anyerror!*Surface,
    createFrameBuffer: *const fn (*anyopaque, Fb.Info) anyerror!*Fb,
    dupe: *const fn (*anyopaque) anyerror!*Device,
    deinit: ?*const fn (*anyopaque) void = null,
};

vtable: *const VTable,
ptr: *anyopaque,

pub inline fn createSurface(self: *Device, info: Surface.Info) anyerror!*Surface {
    return self.vtable.createSurface(self.ptr, info);
}

pub inline fn createFrameBuffer(self: *Device, info: Fb.Info) anyerror!*Fb {
    return self.vtable.createFrameBuffer(self.ptr, info);
}

pub inline fn dupe(self: *Device) !*Device {
    return self.vtable.dupe(self.ptr);
}

pub inline fn deinit(self: *Device) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
