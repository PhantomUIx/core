const std = @import("std");
const Allocator = std.mem.Allocator;
const math = @import("../../../math.zig");
const Context = @import("../../Context.zig");
const z2d = @import("z2d");
const Self = @This();

base: Context.@"2d",
context: z2d.Context,

const vtable: Context.@"2d".VTable = .{
    .getSize = vtable_getSize,
    .render = vtable_render,
    .destroy = vtable_destroy,
};

pub fn create(alloc: Allocator, surface: *z2d.Surface) Allocator.Error!*Context {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .base = Context.@"2d".init(&self.base, self, &vtable),
        .context = z2d.Context.init(alloc, surface),
    };
    return &self.base.base;
}

pub fn getSize(self: *Self) math.Vec2(usize) {
    return math.Vec2(usize).init(
        @intCast(self.context.surface.getWidth()),
        @intCast(self.context.surface.getHeight()),
    );
}

pub fn render(self: *Self, op: Context.@"2d".Operation) anyerror!void {
    switch (op) {
        .rect => |rect| {
            self.context.resetPath();

            self.context.setSource(switch (rect.source) {
                .color => |color| .{ .opaque_pattern = .{ .pixel = .{ .rgba = z2d.pixel.RGBA.fromClamped(
                    color.value[0],
                    color.value[1],
                    color.value[2],
                    color.value[3],
                ) } } },
                .gradient => |gradient| .{ .gradient = @constCast(&gradient.value) },
                else => return error.Unsupported,
            });

            const top_right_radius = rect.border_radius.top_right orelse 0.0;
            const top_left_radius = rect.border_radius.top_left orelse 0.0;

            const bottom_right_radius = rect.border_radius.bottom_right orelse 0.0;
            const bottom_left_radius = rect.border_radius.bottom_left orelse 0.0;

            const degrees = std.math.pi / 180.0;

            const x = rect.rect.position.value[0];
            const y = rect.rect.position.value[1];
            const width = rect.rect.size.value[0];
            const height = rect.rect.size.value[1];

            if (top_right_radius > 0.0) {
                try self.context.arc(
                    x + width - top_right_radius,
                    y + top_right_radius,
                    top_right_radius,
                    -90 * degrees,
                    0 * degrees,
                );
            } else {
                try self.context.lineTo(x + width, y);
            }

            // Bottom-right corner
            if (bottom_right_radius > 0.0) {
                try self.context.arc(
                    x + width - bottom_right_radius,
                    y + height - bottom_right_radius,
                    bottom_right_radius,
                    0 * degrees,
                    90 * degrees,
                );
            } else {
                try self.context.lineTo(x + width, y + height);
            }

            // Bottom-left corner
            if (bottom_left_radius > 0.0) {
                try self.context.arc(
                    x + bottom_left_radius,
                    y + height - bottom_left_radius,
                    bottom_left_radius,
                    90 * degrees,
                    180 * degrees,
                );
            } else {
                try self.context.lineTo(x, y + height);
            }

            // Top-left corner
            if (top_left_radius > 0.0) {
                try self.context.arc(
                    x + top_left_radius,
                    y + top_left_radius,
                    top_left_radius,
                    180 * degrees,
                    270 * degrees,
                );
            } else {
                try self.context.lineTo(x, y);
            }

            try self.context.closePath();

            switch (rect.mode) {
                .fill => try self.context.fill(),
                .stroke => |stroke| {
                    self.context.setLineWidth(stroke.width);
                    try self.context.stroke();
                },
            }
        },
        .path => |path| {
            self.context.resetPath();

            self.context.setSource(switch (path.source) {
                .color => |color| .{ .opaque_pattern = .{ .pixel = .{ .rgba = z2d.pixel.RGBA.fromClamped(
                    color.value[0],
                    color.value[1],
                    color.value[2],
                    color.value[3],
                ) } } },
                .gradient => |gradient| .{ .gradient = @constCast(&gradient.value) },
                else => return error.Unsupported,
            });

            if (path.mode == .dots) {
                for (path.value) |e| {
                    const x: i32 = @intFromFloat(e.value[0]);
                    const y: i32 = @intFromFloat(e.value[1]);
                    self.context.surface.putPixel(x, y, self.context.pattern.getPixel(x, y));
                }
            } else {
                for (path.value, 0..) |e, i| {
                    if (i == 0) {
                        try self.context.moveTo(e.value[0], e.value[1]);
                    } else {
                        try self.context.lineTo(e.value[0], e.value[1]);
                    }
                }

                try self.context.closePath();
            }

            switch (path.mode) {
                .fill => try self.context.fill(),
                .stroke => |stroke| {
                    self.context.setLineWidth(stroke.width);
                    try self.context.stroke();
                },
                else => {},
            }
        },
        .composite => |comp| {
            const size = math.Vec2(usize){ .value = switch (comp.source) {
                .img => |img| .{ img.width, img.height },
                .color => .{ 1, 1 },
                .gradient => .{ 1, 1 },
            } };

            var src = try z2d.Surface.init(.image_surface_rgba, self.context.alloc, @intCast(size.value[0]), @intCast(size.value[1]));
            defer src.deinit(self.context.alloc);

            switch (comp.source) {
                .img => |img| {
                    var it = img.iterator();

                    var x: usize = 0;
                    var y: usize = 0;

                    while (it.next()) |color| {
                        const rgba32 = color.toRgba32();
                        src.putPixel(@intCast(x), @intCast(y), .{ .rgba = .{
                            .r = rgba32.r,
                            .g = rgba32.g,
                            .b = rgba32.b,
                            .a = rgba32.a,
                        } });

                        x += 1;
                        if (x > img.width) {
                            x = 0;
                            y += 1;
                            if (y >= img.height) y = 0;
                        }
                    }
                },
                .color => |color| {
                    const width: usize = @intCast(src.getWidth());
                    const height: usize = @intCast(src.getHeight());

                    for (0..width) |x| {
                        for (0..height) |y| {
                            src.putPixel(@intCast(x), @intCast(y), .{ .rgba = .{
                                .r = @intFromFloat(color.value[0] * 255.0),
                                .g = @intFromFloat(color.value[1] * 255.0),
                                .b = @intFromFloat(color.value[2] * 255.0),
                                .a = @intFromFloat(color.value[3] * 255.0),
                            } });
                        }
                    }
                },
                .gradient => |gradient| {
                    const width: usize = @intCast(src.getWidth());
                    const height: usize = @intCast(src.getHeight());

                    for (0..width) |x| {
                        for (0..height) |y| {
                            src.putPixel(@intCast(x), @intCast(y), gradient.value.getPixel(@intCast(x), @intCast(y)));
                        }
                    }
                },
            }

            self.context.surface.composite(
                &src,
                switch (comp.mode) {
                    .in => .src_in,
                    .over => .src_over,
                },
                @intFromFloat(comp.position.value[0] * @as(f32, @floatFromInt(self.context.surface.getWidth()))),
                @intFromFloat(comp.position.value[1] * @as(f32, @floatFromInt(self.context.surface.getHeight()))),
                .{},
            );
        },
        .setTransform => |trans| {
            self.context.setTransformation(.{
                .ax = trans.value.value[0],
                .by = trans.value.value[1],
                .tx = trans.value.value[2],
                .cx = trans.value.value[3],
                .dy = trans.value.value[4],
                .ty = trans.value.value[5],
            });
        },
        .clear => |clear| {
            self.context.setSourceToPixel(.{ .rgba = .{
                .r = @intFromFloat(clear.color.value[0] * 255.0),
                .g = @intFromFloat(clear.color.value[1] * 255.0),
                .b = @intFromFloat(clear.color.value[2] * 255.0),
                .a = @intFromFloat(clear.color.value[3] * 255.0),
            } });

            const size = self.getSize();

            try self.context.moveTo(0, 0);
            try self.context.lineTo(@floatFromInt(size.value[0]), 0);
            try self.context.lineTo(@floatFromInt(size.value[0]), @floatFromInt(size.value[1]));
            try self.context.lineTo(0, @floatFromInt(size.value[1]));
            try self.context.closePath();

            try self.context.fill();
        },
    }
}

pub fn destroy(self: *Self) void {
    self.context.deinit();
    self.context.alloc.destroy(self);
}

fn vtable_getSize(ptr: *anyopaque) math.Vec2(usize) {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.getSize();
}

fn vtable_render(ptr: *anyopaque, op: Context.@"2d".Operation) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.render(op);
}

fn vtable_destroy(ptr: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.destroy();
}
