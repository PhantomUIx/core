const std = @import("std");
const vizops = @import("vizops");
const fb = @import("../painting/fb.zig");
const Surface = @This();

pub const Blt = enum { from, to };

pub const Info = struct {
    format: u32,
    size: vizops.vector.UsizeVector2,
};

pub const VTable = struct {
    info: *const fn (*anyopaque) anyerror!Info,
    updateInfo: *const fn (*anyopaque, Info) anyerror!void,
    blt: *const fn (*anyopaque, Blt, *fb.Base) anyerror!void,
    dupe: *const fn (*anyopaque) anyerror!*Surface,
    deinit: ?*const fn (*anyopaque) void = null,
};

vtable: *const VTable,
ptr: *anyopaque,

pub inline fn info(self: *Surface) !Info {
    return self.vtable.info(self.ptr);
}

pub inline fn updateInfo(self: *Surface, i: Info) !void {
    return self.vtable.updateInfo(self.ptr, i);
}

pub inline fn blt(self: *Surface, mode: Blt, op: *fb.Base) !void {
    return self.vtable.blt(self.ptr, mode, op);
}

pub inline fn dupe(self: *Surface) !*Surface {
    return self.vtable.dupe(self.ptr);
}

pub inline fn deinit(self: *Surface) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
