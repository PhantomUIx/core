const std = @import("std");
const math = @import("../math.zig");
const graphics = @import("../graphics.zig");
const Context = @import("Context.zig");
const Surface = @This();

pub const VTable = struct {
    getSize: *const fn (self: *anyopaque) math.Vec2(usize),
    getFormat: *const fn (self: *anyopaque) ?graphics.Format,
    getBuffer: *const fn (self: *anyopaque) ?[]const u8,
    getContext: *const fn (self: *anyopaque, kind: Context.Kind) Context.Error!*Context,
    snapshot: *const fn (self: *anyopaque) anyerror!graphics.Source,
    destroy: *const fn (self: *anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn getSize(self: *const Surface) math.Vec2(usize) {
    return self.vtable.getSize(self.ptr);
}

pub inline fn getFormat(self: *const Surface) ?graphics.Format {
    return self.vtable.getFormat(self.ptr);
}

pub inline fn getBuffer(self: *const Surface) ?[]const u8 {
    return self.vtable.getBuffer(self.ptr);
}

pub inline fn getContext(self: *Surface, kind: Context.Kind) Context.Error!*Context {
    return self.vtable.getContext(self.ptr, kind);
}

pub inline fn snapshot(self: *Surface) anyerror!graphics.Source {
    return self.vtable.snapshot(self.ptr);
}

pub inline fn destroy(self: *const Surface) void {
    return self.vtable.destroy(self.ptr);
}
