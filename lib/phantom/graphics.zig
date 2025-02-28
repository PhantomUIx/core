//! Core graphics API
const std = @import("std");
const zigimg = @import("zigimg");
const z2d = @import("z2d");

pub const backend = @import("graphics/backend.zig");

pub const Color = @import("graphics/Color.zig");
pub const Context = @import("graphics/Context.zig");
pub const Surface = @import("graphics/Surface.zig");

pub const Format = enum {
    argb32,
    rgba32,
    rgbx32,
    rgb24,

    pub fn channels(self: Format) u8 {
        return switch (self) {
            .argb32, .rgba32 => 4,
            .rgbx32, .rgb24 => 3,
        };
    }

    pub fn asZigimg(self: Format) zigimg.PixelFormat {
        return switch (self) {
            .rgba32 => .rgba32,
            .rgb24 => .rgb24,
            else => .invalid,
        };
    }
};

pub const Subpixel = enum {
    horiz_rgb,
    horiz_bgr,
    vert_rgb,
    vert_bgr,

    pub fn isHorizontal(self: Subpixel) bool {
        return switch (self) {
            .horiz_rgb, .horiz_bgr => true,
            else => false,
        };
    }

    pub fn isVertical(self: Subpixel) bool {
        return switch (self) {
            .vert_rgb, .vert_bgr => true,
            else => false,
        };
    }

    pub fn isRgb(self: Subpixel) bool {
        return switch (self) {
            .horiz_rgb, .vert_rgb => true,
            else => false,
        };
    }

    pub fn isBgr(self: Subpixel) bool {
        return switch (self) {
            .horiz_bgr, .vert_bgr => true,
            else => false,
        };
    }
};

pub const Gradient = struct {
    allocator: std.mem.Allocator,
    value: z2d.Gradient,

    pub inline fn deinit(self: *Gradient) void {
        return self.value.deinit(self.allocator);
    }
};

pub const Source = union(enum) {
    img: zigimg.Image,
    color: Color,
    gradient: Gradient,

    pub fn destroy(self: *Source) void {
        return switch (self.*) {
            .img => |*img| img.deinit(),
            .gradient => |*gradient| gradient.deinit(),
            else => {},
        };
    }
};

test {
    _ = backend;
    _ = Color;
    _ = Context;
    _ = Surface;
}
