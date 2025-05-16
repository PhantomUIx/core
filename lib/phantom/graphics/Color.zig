const std = @import("std");
const Value = @Vector(4, f16);
const Color = @This();

value: Value,

pub inline fn init(value: Value) Color {
    return .{ .value = value };
}

pub const black = init(.{ 0, 0, 0, 1 });
pub const white = init(.{ 1, 1, 1, 1 });
