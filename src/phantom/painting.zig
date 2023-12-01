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

pub const fb = @import("painting/fb.zig");
pub const image = @import("painting/image.zig");
