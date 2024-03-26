const std = @import("std");
const vizops = @import("vizops");
const Fb = @import("fb/base.zig");
const painting = @import("../painting.zig");
const Self = @This();

pub const Options = struct {
    pos: ?vizops.vector.UsizeVector2,
    size: ?vizops.vector.UsizeVector2,
};

fb: *Fb,
bounds: vizops.vector.UsizeVector4,

pub fn init(fb: *Fb, options: Options) Self {
    const pos = if (options.pos) |value| value else vizops.vector.UsizeVector2.zero();
    const size = if (options.size) |value| value else fb.info().res;
    return .{
        .fb = fb,
        .bounds = .{ .value = std.simd.join(pos.value, size.value) },
    };
}

pub fn setPixel(self: *const Self, pos: vizops.vector.UsizeVector2, buffer: []const u8) !void {
    const bufferInfo = self.fb.info();
    const stride = buffer.len * bufferInfo.res.value[0];
    const index = ((pos.value[1] + self.bounds.value[1]) * stride) + ((pos.value[0] + self.bounds.value[0]) * buffer.len);
    try self.fb.write(index, buffer);
}

pub fn line(self: *const Self, start: vizops.vector.UsizeVector2, end: vizops.vector.UsizeVector2, buffer: []const u8) !void {
    var x0 = start.value[0];
    var y0 = start.value[1];
    const x1 = end.value[0];
    const y1 = end.value[1];

    const dx = @max(x1, x0) - @min(x0, x1);
    const sx = if (x0 < x1) @as(isize, 1) else @as(isize, -1);
    const dy = @as(usize, @intCast(@as(isize, @intCast(@abs(y1 - y0))) * @as(isize, -1)));
    const sy = if (y0 < y1) @as(isize, 1) else @as(isize, -1);
    var err = dx + dy;

    while (true) {
        try self.setPixel(vizops.vector.UsizeVector2.init([_]usize{ x0, y0 }), buffer);

        if (x0 == x1 and y0 == y1) break;

        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            if (sx < 0) {
                x0 -= 1;
            } else {
                x0 += 1;
            }
        }
        if (e2 <= dx) {
            err += dx;
            if (sy < 0) {
                y0 -= 1;
            } else {
                y0 += 1;
            }
        }
    }
}

pub fn arc(self: *const Self, pos: vizops.vector.UsizeVector2, angles: vizops.vector.Float32Vector2, radius: f32, buffer: []const u8) !void {
    const startAngle = std.math.degreesToRadians(angles.value[0]);
    const endAngle = std.math.degreesToRadians(angles.value[1]);

    const center = vizops.vector.UsizeVector2.init([_]usize{
        pos.value[0] - std.math.lossyCast(usize, @cos(startAngle) * radius),
        pos.value[1] - std.math.lossyCast(usize, @sin(startAngle) * radius),
    });

    var r: f32 = 0;
    while (r <= radius) : (r += 1.0) {
        var angle = startAngle;
        while (angle <= endAngle) : (angle += 1.0 / r) {
            const x = center.value[0] + std.math.lossyCast(usize, r * @cos(angle));
            const y = center.value[1] + std.math.lossyCast(usize, r * @sin(angle));

            try self.setPixel(vizops.vector.UsizeVector2.init([_]usize{ x, y }), buffer);
        }
    }
}

pub fn circle(self: *const Self, pos: vizops.vector.UsizeVector2, radius: usize, buffer: []const u8) !void {
    const circumferencePoint = vizops.vector.UsizeVector2.init([_]usize{ pos.value[0] + std.math.round(radius), pos.value[1] });
    const fullCircle = vizops.vector.UsizeVector2.init([_]usize{ 0, 360 });
    try self.arc(circumferencePoint, fullCircle, radius, buffer);
}

pub fn rect(self: *const Self, pos: vizops.vector.UsizeVector2, size: vizops.vector.UsizeVector2, radius: painting.Radius(f32), buffer: []const u8) !void {
    const x = pos.value[0];
    const y = pos.value[1];
    const width = size.value[0];
    const height = size.value[1];

    const topLeftRadius = (if (radius.top) |top| top.left else null) orelse @as(f32, 0);
    const topRightRadius = (if (radius.top) |top| top.right else null) orelse @as(f32, 0);
    const bottomLeftRadius = (if (radius.bottom) |bottom| bottom.left else null) orelse @as(f32, 0);
    const bottomRightRadius = (if (radius.bottom) |bottom| bottom.right else null) orelse @as(f32, 0);

    if (topLeftRadius > 0) {
        try self.arc(vizops.vector.UsizeVector2.init([_]usize{ x, y }), vizops.vector.Float32Vector2.init([_]f32{ 180, 270 }), topLeftRadius, buffer);
    }
    if (topRightRadius > 0) {
        try self.arc(vizops.vector.UsizeVector2.init([_]usize{ x + width, y }), vizops.vector.Float32Vector2.init([_]f32{ 270, 360 }), topRightRadius, buffer);
    }
    if (bottomLeftRadius > 0) {
        try self.arc(vizops.vector.UsizeVector2.init([_]usize{ x, y + height }), vizops.vector.Float32Vector2.init([_]f32{ 90, 180 }), bottomLeftRadius, buffer);
    }
    if (bottomRightRadius > 0) {
        try self.arc(vizops.vector.UsizeVector2.init([_]usize{ x + width, y + height }), vizops.vector.Float32Vector2.init([_]f32{ 0, 90 }), bottomRightRadius, buffer);
    }

    const leftEdge = x + std.math.lossyCast(usize, @max(topLeftRadius, bottomLeftRadius));
    const rightEdge = x + width - std.math.lossyCast(usize, @max(topRightRadius, bottomRightRadius));
    var i: usize = y;
    while (i < y + height) : (i += 1) {
        for (leftEdge..rightEdge) |xp| {
            try self.setPixel(vizops.vector.UsizeVector2.init([_]usize{ xp, i }), buffer);
        }
    }
}
