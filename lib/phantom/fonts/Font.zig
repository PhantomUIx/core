const std = @import("std");
const graphics = @import("../graphics.zig");
const math = @import("../math.zig");
const Self = @This();

pub const Glyph = struct {
    index: u32,
    image: graphics.Source,
    size: math.Vec2(u8),
    bearing: math.Vec2(i8),
    advance: math.Vec2(i8),
};

pub const VTable = struct {
    lookupGlyph: *const fn (*anyopaque, u21) anyerror!Glyph,
    getSize: *const fn (*anyopaque) math.Vec2(usize),
    getLabel: *const fn (*anyopaque) ?[]const u8,
    deinit: *const fn (*anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn lookupGlyph(self: *Self, codepoint: u21) !Glyph {
    return self.vtable.lookupGlyph(self.ptr, codepoint);
}

pub inline fn getSize(self: *Self) math.Vec2(usize) {
    return self.vtable.getSize(self.ptr);
}

pub inline fn getLabel(self: *Self) ?[]const u8 {
    return self.vtable.getLabel(self.ptr);
}

pub inline fn deinit(self: *Self) void {
    return self.vtable.deinit(self.ptr);
}
