const std = @import("std");
const painting = @import("../painting.zig");
const vizops = @import("vizops");
const Self = @This();

pub const Glyph = struct {
    index: u32,
    fb: *painting.fb.Base,
    size: vizops.vector.Uint8Vector2,
    bearing: vizops.vector.Int8Vector2,
    advance: vizops.vector.Int8Vector2,
};

pub const VTable = struct {
    lookupGlyph: *const fn (*anyopaque, u21) anyerror!Glyph = null,
    getSize: *const fn (*anyopaque) vizops.vector.UsizeVector2,
    deinit: ?*const fn (*anyopaque) void = null,
};

vtable: *const VTable,
ptr: *anyopaque,

pub inline fn lookupGlyph(self: *Self, codepoint: u21) !Glyph {
    return self.vtable.lookupGlyph(self.ptr, codepoint);
}

pub inline fn getSize(self: *Self) vizops.vector.UsizeVector2 {
    return self.vtable.getSize(self.ptr);
}

pub inline fn deinit(self: *Self) void {
    return if (self.vtable.deinit) |f| f(self.ptr) else {};
}
