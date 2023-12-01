const std = @import("std");
const vizops = @import("vizops");
const Fb = @import("../fb/base.zig");
const Self = @This();

pub const Info = struct {
    res: vizops.vector.UsizeVector2,
    colorFormat: vizops.color.fourcc.Value,
    colorspace: std.meta.DeclEnum(vizops.color.types),
    seqCount: usize,
};

pub const VTable = struct {
    buffer: *const fn (*anyopaque, usize) anyerror!*Fb,
    info: *const fn (*anyopaque) Info,
    deinit: ?*const fn (*anyopaque) void = null,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn buffer(self: Self) !*Fb {
    return self.vtable.buffer(self.ptr);
}

pub inline fn info(self: Self) Info {
    return self.vtable.info(self.ptr);
}

pub inline fn deinit(self: Self) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
