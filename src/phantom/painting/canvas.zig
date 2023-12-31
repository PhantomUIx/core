const std = @import("std");
const vizops = @import("vizops");
const Fb = @import("fb/base.zig");
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

pub fn setPixel(self: *const Self, pos: vizops.vector.UsizeVector2, color: vizops.color.Any) !void {
    const bufferInfo = self.fb.info();
    if ((pos.value[0] + self.bounds.value[0]) >= self.bounds.value[2]) return;
    if ((pos.value[1] + self.bounds.value[1]) >= self.bounds.value[3]) return;

    const buffer = try self.fb.allocator.alloc(u8, @divExact(bufferInfo.colorFormat.width(), 8));
    defer self.fb.allocator.free(buffer);
    try vizops.color.writeAnyBuffer(bufferInfo.colorFormat, buffer, color);

    const stride = buffer.len * bufferInfo.res.value[0];
    const index = ((pos.value[1] + self.bounds.value[1]) * stride) + ((pos.value[0] + self.bounds.value[0]) * buffer.len);
    try self.fb.write(index, buffer);
}

pub fn lineHoriz(self: *const Self, pos: vizops.vector.UsizeVector2, length: usize, color: vizops.color.Any) !void {
    const realY = pos.value[1] + self.bounds.value[1];

    const bufferInfo = self.fb.info();

    const buffer = try self.fb.allocator.alloc(u8, @divExact(bufferInfo.colorFormat.width(), 8));
    defer self.fb.allocator.free(buffer);
    try vizops.color.writeAnyBuffer(bufferInfo.colorFormat, buffer, color);

    const stride = buffer.len * bufferInfo.res.value[0];

    for (0..length) |x| {
        const realX = pos.value[0] + x + self.bounds.value[0];
        if (realX >= self.bounds.value[2]) break;

        const index = (realY * stride) + (realX * buffer.len);
        try self.fb.write(index, buffer);
    }
}

pub fn strokeLine(self: *const Self, start: vizops.vector.UsizeVector2, end: vizops.vector.UsizeVector2, color: vizops.color.Any) !void {
    const d = end.sub(start);

    if (d.value[1] == 0) {
        if (d.value[0] == 0) return;
        return self.lineHoriz(start, end.value[0], color);
    }

    try self.setPixel(start, color);
    if (d.value[0] > d.value[1]) {
        var frac = d.value[1] - (d.value[0] >> 1);
        var pos = start;
        while (pos.value[0] != end.value[0]) {
            if (frac >= 0) {
                pos.value[1] += 1;
                frac -= pos.value[0];
            }

            pos.value[0] += 1;
            frac += pos.value[1];
            try self.setPixel(pos, color);
        }
    } else {
        var frac = d.value[0] - (d.value[1] >> 1);
        var pos = start;
        while (pos.value[1] != end.value[1]) {
            if (frac >= 0) {
                pos.value[0] += 1;
                frac -= pos.value[1];
            }

            pos.value[1] += 1;
            frac += pos.value[0];
            try self.setPixel(pos, color);
        }
    }
}

pub fn fillPolygon(self: *const Self, points: []vizops.vector.UsizeVector2, color: vizops.color.Any) !void {
    var size = vizops.vector.UsizeVector4.zero();

    for (points) |p| {
        if (size.value[0] > p.value[0]) {
            size.value[0] = p.value[0];
        }

        if (size.value[1] < p.value[0]) {
            size.value[1] = p.value[0];
        }

        if (size.value[2] > p.value[1]) {
            size.value[2] = p.value[1];
        }

        if (size.value[3] < p.value[1]) {
            size.value[3] = p.value[1];
        }
    }

    size.value[1] += 1;
    size.value[3] += 1;

    var nodes = std.ArrayList(usize).init(self.fb.allocator);
    defer nodes.deinit();

    var y = size.value[2];
    while (y < size.value[3]) : (y += 1) {
        var j = points.len - 1;

        nodes.clearAndFree();
        for (points, 0..) |p, i| {
            if (((p.value[1] < y) and (points[j].value[1] >= y)) or ((points[j].value[1] < y) and (p.value[1] >= y))) {
                try nodes.append(p.value[0] + (y - p.value[1]) / (points[j].value[1] - p.value[1]) * (points[j].value[0] - p.value[0]));
            }

            j = i;
        }

        var i: usize = 0;
        while (i < (points.len - 1)) {
            if (nodes.items[i] > nodes.items[i + 1]) {
                const swap = nodes.items[i];
                nodes.items[i] = nodes.items[i + 1];
                nodes.items[i + 1] = swap;
                if (i > 0) i -= 1;
            } else i += 1;
        }

        i = 0;
        while (i < nodes.items.len) : (i += 2) {
            if (nodes.items[i] >= size.value[1]) break;
            if (nodes.items[i + 1] > size.value[0]) {
                if (nodes.items[i] < size.value[0]) nodes.items[i] = size.value[0];
                if (nodes.items[i + 1] > size.value[1]) nodes.items[i + 1] = size.value[1];

                var x = nodes.items[i];
                while (x < nodes.items[i + 1]) : (x += 1) {
                    try self.setPixel(vizops.vector.UsizeVector2.init([_]usize{ x, y }), color);
                }
            }
        }
    }
}

pub fn fillArc(self: *const Self, pos: vizops.vector.UsizeVector2, size: vizops.vector.UsizeVector2, s: u16, color: vizops.color.Any) !void {
    var x0 = pos.value[0];
    var y0 = pos.value[1];
    var w = size.value[0];
    var h = size.value[1];

    const a2 = (w * w) / 4;
    const b2 = (h * h) / 4;
    const fa2 = 4 * a2;
    const fb2 = 4 * b2;

    if (w < 1 or h < 1) return;
    if (s != 0 and s != 90 and s != 180 and s != 270) return;

    h = (h + 1) / 2;
    w = (w + 1) / 2;
    x0 += w;
    y0 += h;

    var points: [3]vizops.vector.UsizeVector2 = undefined;
    points[0] = vizops.vector.UsizeVector2.init([_]usize{ x0, y0 });
    points[2] = vizops.vector.UsizeVector2.init([_]usize{ x0, y0 });

    var x: usize = 0;
    var y = h;
    var sigma: usize = 2 * b2 + a2 * (1 - 2 * h);
    while ((b2 * x) <= (a2 * y)) : (x += 1) {
        points[1] = switch (s) {
            180 => vizops.vector.UsizeVector2.init([_]usize{ x0 + x, y0 + y }),
            270 => vizops.vector.UsizeVector2.init([_]usize{ x0 - x, y0 + y }),
            0 => vizops.vector.UsizeVector2.init([_]usize{ x0 + x, y0 - y }),
            90 => vizops.vector.UsizeVector2.init([_]usize{ x0 - x, y0 - y }),
            else => vizops.vector.UsizeVector2.zero(),
        };

        try self.fillPolygon(&points, color);
        points[2] = points[1];

        if (sigma >= 0) {
            sigma += fa2 * (1 - y);
            y -= 1;
        }

        sigma += b2 * ((4 * x) + 6);
    }

    x = w;
    y = 0;
    sigma = 2 * a2 + b2 * (1 - 2 * w);
    while ((a2 * y) <= (b2 * x)) : (y += 1) {
        points[1] = switch (s) {
            180 => vizops.vector.UsizeVector2.init([_]usize{ x0 + x, y0 + y }),
            270 => vizops.vector.UsizeVector2.init([_]usize{ x0 - x, y0 + y }),
            0 => vizops.vector.UsizeVector2.init([_]usize{ x0 + x, y0 - y }),
            90 => vizops.vector.UsizeVector2.init([_]usize{ x0 - x, y0 - y }),
            else => vizops.vector.UsizeVector2.zero(),
        };

        try self.fillPolygon(&points, color);
        points[2] = points[1];

        if (sigma >= 0) {
            sigma += fb2 * (1 - x);
            x -= 1;
        }

        sigma += a2 * ((4 * y) + 6);
    }
}

pub fn fillRect(self: *const Self, pos: vizops.vector.UsizeVector2, size: vizops.vector.UsizeVector2, r: u16, color: vizops.color.Any) !void {
    if (r == 0) {
        for (0..size.value[1]) |i| {
            try self.strokeLine(pos.add(vizops.vector.UsizeVector2.init([_]usize{
                0,
                i,
            })), pos.add(vizops.vector.UsizeVector2.init([_]usize{
                size.value[0],
                i,
            })), color);
        }
    } else {
        const xc = pos.value[0] + r;
        const yc = pos.value[1] + r;
        const wc = size.value[0] - 2 * r;
        const hc = size.value[1] - 2 * r;

        var points: [12]vizops.vector.UsizeVector2 = undefined;
        points[0] = vizops.vector.UsizeVector2.init([_]usize{ pos.value[0], yc });
        points[1] = vizops.vector.UsizeVector2.init([_]usize{ xc, yc });
        points[2] = vizops.vector.UsizeVector2.init([_]usize{ xc, pos.value[1] });
        points[3] = vizops.vector.UsizeVector2.init([_]usize{ xc + wc, pos.value[1] });
        points[4] = vizops.vector.UsizeVector2.init([_]usize{ xc + wc, yc });
        points[5] = vizops.vector.UsizeVector2.init([_]usize{ pos.value[0] + size.value[0], yc });
        points[6] = vizops.vector.UsizeVector2.init([_]usize{ pos.value[0] + size.value[0], yc + hc });
        points[7] = vizops.vector.UsizeVector2.init([_]usize{ xc + wc, yc + hc });
        points[8] = vizops.vector.UsizeVector2.init([_]usize{ xc + wc, pos.value[1] + size.value[1] });
        points[9] = vizops.vector.UsizeVector2.init([_]usize{ xc, pos.value[1] + size.value[1] });
        points[10] = vizops.vector.UsizeVector2.init([_]usize{ xc, yc + hc });
        points[11] = vizops.vector.UsizeVector2.init([_]usize{ pos.value[0], yc + hc });

        try self.fillPolygon(&points, color);

        try self.fillArc(vizops.vector.UsizeVector2.init([_]usize{ xc + wc - r, pos.value[1] }), vizops.vector.UsizeVector2.init(r * 2), 0, color);
        try self.fillArc(pos, vizops.vector.UsizeVector2.init(r * 2), 90, color);
        try self.fillArc(vizops.vector.UsizeVector2.init([_]usize{ pos.value[0], yc + hc - r }), vizops.vector.UsizeVector2.init(r * 2), 270, color);
        try self.fillArc(vizops.vector.UsizeVector2.init([_]usize{ xc + wc - r, yc + hc - r }), vizops.vector.UsizeVector2.init(r * 2), 180, color);
    }
}
