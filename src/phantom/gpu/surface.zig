const std = @import("std");
const vizops = @import("vizops");
const Surface = @This();

pub const Info = struct {
    format: u32,
    size: vizops.vector.UsizeVector2 = vizops.vector.UsizeVector2.zero(),
};

pub const VTable = struct {
    info: *const fn (*anyopaque) anyerror!Info,
    dupe: *const fn (*anyopaque) anyerror!*Surface,
    deinit: ?*const fn (*anyopaque) void = null,
};

vtable: *const VTable,
ptr: *anyopaque,

pub inline fn info(self: *Surface) !Info {
    return self.vtable.info(self.ptr);
}

pub inline fn dupe(self: *Surface) !*Surface {
    return self.vtable.dupe(self.ptr);
}

pub inline fn deinit(self: *Surface) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
