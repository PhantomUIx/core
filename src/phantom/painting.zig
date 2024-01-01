const std = @import("std");
const vizops = @import("vizops");

pub const Axis = enum {
    horizontal,
    vertical,
};

pub const Blt = enum { from, to };

pub const BltOptions = struct {
    sourceOffset: vizops.vector.UsizeVector2 = .{},
    destOffset: vizops.vector.UsizeVector2 = .{},
    size: ?vizops.vector.UsizeVector2 = null,
    blend: vizops.color.BlendMode = .normal,
};

pub fn Radius(comptime T: type) type {
    return struct {
        const Self = @This();

        top: ?Side = null,
        bottom: ?Side = null,

        pub fn equal(self: Self, other: Self) bool {
            return std.simd.countTrues(@Vector(2, bool){
                if (self.top == null and other.top != null) false else if (self.top != null and other.top == null) false else self.top.?.equal(other.top.?),
                if (self.bottom == null and other.bottom != null) false else if (self.bottom != null and other.bottom == null) false else self.bottom.?.equal(other.bottom.?),
            }) == 2;
        }

        pub const Side = struct {
            left: ?T = null,
            right: ?T = null,

            pub fn equal(self: Side, other: Side) bool {
                return std.simd.countTrues(@Vector(2, bool){
                    self.left == other.left,
                    self.right == other.right,
                }) == 2;
            }
        };
    };
}

pub const fb = @import("painting/fb.zig");
pub const image = @import("painting/image.zig");
pub const Canvas = @import("painting/canvas.zig");
