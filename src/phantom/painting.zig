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

pub const RadiusSide = struct {
    left: ?f32 = null,
    right: ?f32 = null,

    pub fn equal(self: RadiusSide, other: RadiusSide) bool {
        return std.simd.countTrues(@Vector(2, bool){
            self.left == other.left,
            self.right == other.right,
        }) == 2;
    }
};

pub const Radius = struct {
    top: ?RadiusSide = null,
    bottom: ?RadiusSide = null,

    pub fn equal(self: Radius, other: Radius) bool {
        return std.simd.countTrues(@Vector(2, bool){
            if (self.top == null and other.top != null) false else if (self.top != null and other.top == null) false else self.top.?.equal(other.top.?),
            if (self.bottom == null and other.bottom != null) false else if (self.bottom != null and other.bottom == null) false else self.bottom.?.equal(other.bottom.?),
        }) == 2;
    }
};

pub const fb = @import("painting/fb.zig");
pub const image = @import("painting/image.zig");
pub const Canvas = @import("painting/canvas.zig");
