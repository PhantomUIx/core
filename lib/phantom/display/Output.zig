const std = @import("std");
const graphics = @import("../graphics.zig");
const math = @import("../math.zig");
const Self = @This();

pub const Mode = struct {
    enabled: bool,
    res: math.Vec2(usize),
    scale: math.Vec2(f32),
    format: graphics.Format,
};

pub const Info = struct {
    phys_size: math.Vec2(f32),
    name: []const u8,
    manufacturer: []const u8,
};

pub const VTable = struct {
    getModes: *const fn (*anyopaque) []const Mode,
    testMode: *const fn (*anyopaque, Mode) bool,
    setMode: *const fn (*anyopaque, Mode) anyerror!void,
    getInfo: *const fn (*anyopaque) ?Info,
    destroy: *const fn (*anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn getModes(self: *Self) []const Mode {
    return self.vtable.getModes(self.ptr);
}

pub inline fn testMode(self: *Self, mode: Mode) bool {
    return self.vtable.testMode(self.ptr, mode);
}

pub inline fn setMode(self: *Self, mode: Mode) anyerror!void {
    return self.vtable.setMode(self.ptr, mode);
}

pub inline fn getInfo(self: *Self) ?Info {
    return self.vtable.getInfo(self.ptr);
}

pub inline fn destroy(self: *Self) void {
    return self.vtable.destroy(self.ptr);
}
