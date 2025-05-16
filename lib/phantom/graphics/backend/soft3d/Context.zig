const std = @import("std");
const Allocator = std.mem.Allocator;
const graphics = @import("../../../graphics.zig");
const math = @import("../../../math.zig");
const Context = @import("../../Context.zig");
const Self = @This();

allocator: Allocator,
base: Context.@"3d",
context: *Context,
proj: math.Mat4x4(f32),
depth: Depth,

const Depth = union(enum) {
    zbuffer: struct {
        buffer: []f32,
    },
    culling: void,
    none: void,
};

const vtable: Context.@"3d".VTable = .{
    .getSize = vtable_getSize,
    .render = vtable_render,
    .destroy = vtable_destroy,
};

pub fn create(alloc: Allocator, ctx: *Context) Allocator.Error!*Context {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .base = Context.@"3d".init(&self.base, self, &vtable),
        .context = ctx,
        .proj = math.mat4x4.identity(f32),
        .depth = .none,
    };
    return &self.base.base;
}

pub fn getSize(self: *Self) math.Vec2(usize) {
    return self.context.getSize();
}

pub fn render(self: *Self, op: Context.@"3d".Operation) anyerror!void {
    switch (op) {
        .polygon => |polygon| {
            const mvp = math.mat4x4.mult(f32, self.proj, math.mat4x4.mult(f32, polygon.view, polygon.model));

            var path = std.ArrayList(math.Vec2(f32)).init(self.allocator);
            defer path.deinit();

            const size = self.getSize();
            const half_size = size.divValue(@splat(2));
            const size_min1 = size.subValue(@splat(1));

            for (polygon.indices) |indice| {
                const v = math.mat4x4.multVec(f32, mvp, polygon.vertices[indice]);

                const x = @as(f32, @floatFromInt(half_size.value[0])) + v.value[0] / v.value[3] * @as(f32, @floatFromInt(half_size.value[0]));
                const y = @as(f32, @floatFromInt(half_size.value[1])) - v.value[1] / v.value[3] * @as(f32, @floatFromInt(half_size.value[1]));

                try path.append(math.Vec2(f32).init(x, y));
            }

            if (self.depth == .zbuffer and path.items.len > 2) {
                const ndc_zs = try self.allocator.alloc(f32, path.items.len);
                defer self.allocator.free(ndc_zs);

                for (polygon.indices, 0..) |indice, i| {
                    const v = math.mat4x4.multVec(f32, mvp, polygon.vertices[indice]);
                    ndc_zs[i] = v.value[2] / v.value[3];
                }

                for (1..(path.items.len - 1)) |i| {
                    const tri = [3]usize{ 0, i, i + 1 };

                    const v0 = path.items[tri[0]];
                    const v1 = path.items[tri[1]];
                    const v2 = path.items[tri[2]];

                    const z0 = ndc_zs[tri[0]];
                    const z1 = ndc_zs[tri[1]];
                    const z2 = ndc_zs[tri[2]];

                    const min: math.Vec2(f32) = .{ .value = @min(@min(v0.value, v1.value), v2.value) };
                    const max: math.Vec2(f32) = .{ .value = @max(@Vector(2, f32){
                        @floatFromInt(size_min1.value[0]),
                        @floatFromInt(size_min1.value[1]),
                    }, @max(@max(v0.value, v1.value), v2.value)) };

                    for (@intFromFloat(min.value[1])..@intFromFloat(max.value[1] + 1)) |py| {
                        for (@intFromFloat(min.value[0])..@intFromFloat(max.value[0] + 1)) |px| {
                            const bary = math.mat4x4.computeBarycentric(f32, v0, v1, v2, @floatFromInt(px), @floatFromInt(py));
                            if (bary.value[0] < 0 or bary.value[1] < 0 or bary.value[2] < 0) continue;

                            const z = bary.value[0] * z0 + bary.value[1] * z1 + bary.value[2] * z2;
                            const index = py * size.value[0] + px;

                            if (z < self.depth.zbuffer.buffer[index]) {
                                self.depth.zbuffer.buffer[index] = z;
                                try self.context.render(.{ .@"2d" = .{ .path = .{
                                    .value = &[_]math.Vec2(f32){math.Vec2(f32).init(@floatFromInt(px), @floatFromInt(py))},
                                    .source = polygon.source,
                                    .mode = .dots,
                                } } });
                            }
                        }
                    }
                }
                return;
            }

            if (self.depth == .culling and path.items.len > 2) {
                const p0 = path.items[0];
                const p1 = path.items[1];
                const p2 = path.items[2];

                const d1 = p1.sub(p0);
                const d2 = p2.sub(p0);

                const signed_area = d1.value[0] * d2.value[1] - d1.value[1] * d2.value[0];
                if (signed_area < 0) return;
            }

            try self.context.render(.{ .@"2d" = .{ .path = .{
                .value = path.items,
                .source = polygon.source,
                .mode = .fill,
            } } });
        },
        .setProjection => |proj| {
            self.proj = proj.value;
        },
        .clear => |clear| {
            if (clear.color) |color| {
                try self.context.render(.{ .@"2d" = .{ .clear = .{ .color = color } } });
            }

            if (clear.depth) |depth| {
                if (self.depth == .zbuffer) {
                    self.allocator.free(self.depth.zbuffer.buffer);
                }

                self.depth = switch (depth) {
                    .zbuffer => .{ .zbuffer = blk: {
                        const buff = try self.allocator.alloc(f32, self.getSize().value[0] * self.getSize().value[1]);
                        @memset(buff, 1.0);
                        break :blk .{ .buffer = buff };
                    } },
                    inline else => |value, tag| @unionInit(Depth, @tagName(tag), value),
                };
            }
        },
    }
}

pub fn destroy(self: *Self) void {
    if (self.depth == .zbuffer) {
        self.allocator.free(self.depth.zbuffer.buffer);
    }
    self.allocator.destroy(self);
}

fn vtable_getSize(ptr: *anyopaque) math.Vec2(usize) {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.getSize();
}

fn vtable_render(ptr: *anyopaque, op: Context.@"3d".Operation) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.render(op);
}

fn vtable_destroy(ptr: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.destroy();
}

test {
    const surface = try @import("../z2d.zig").Surface.create(std.testing.allocator, .rgba32, 800, 600);
    defer surface.destroy();

    const ctx2d = try surface.getContext(.@"2d");
    defer ctx2d.destroy();

    const ctx = try create(std.testing.allocator, ctx2d);
    defer ctx.destroy();

    try ctx.render(.{
        .@"3d" = .{
            .clear = .{
                .color = graphics.Color.white,
                .depth = .zbuffer,
            },
        },
    });

    try ctx.render(.{
        .@"3d" = .{
            .setProjection = .{
                .value = math.mat4x4.perspective(
                    f32,
                    std.math.pi / 2.5,
                    @as(f32, @floatFromInt(surface.getSize().value[0])) / @as(f32, @floatFromInt(surface.getSize().value[1])),
                    0.1,
                    100,
                ),
            },
        },
    });

    var cube: [8]math.Vec4(f32) = .{
        math.Vec4(f32).init(-1, -1, -1, 1), math.Vec4(f32).init(1, -1, -1, 1),
        math.Vec4(f32).init(1, 1, -1, 1),   math.Vec4(f32).init(-1, 1, -1, 1),
        math.Vec4(f32).init(-1, -1, 1, 1),  math.Vec4(f32).init(1, -1, 1, 1),
        math.Vec4(f32).init(1, 1, 1, 1),    math.Vec4(f32).init(-1, 1, 1, 1),
    };

    var faces: [6][4]usize = .{
        .{ 0, 1, 2, 3 }, // bottom face (z = -1)
        .{ 7, 6, 5, 4 }, // top face (z = 1)
        .{ 4, 5, 1, 0 }, // front face (y = -1)
        .{ 3, 2, 6, 7 }, // back face (y = 1)
        .{ 0, 3, 7, 4 }, // left face (x = -1)
        .{ 5, 6, 2, 1 }, // right face (x = 1)
    };

    const colors: [6]graphics.Color = .{
        graphics.Color.init(.{ 0.2, 0.6, 1.0, 1.0 }),
        graphics.Color.init(.{ 0.6, 0.2, 1.0, 1.0 }),
        graphics.Color.init(.{ 0.2, 1.0, 0.6, 1.0 }),
        graphics.Color.init(.{ 1.0, 0.6, 0.2, 1.0 }),
        graphics.Color.init(.{ 1.0, 0.2, 0.4, 1.0 }),
        graphics.Color.init(.{ 1.0, 1.0, 0.3, 1.0 }),
    };

    const view = math.mat4x4.translate(f32, 0, 0, -4);
    const model = math.mat4x4.mult(f32, math.mat4x4.rotateY(f32, std.math.pi / 6.0), math.mat4x4.rotateX(f32, std.math.pi / 8.0));

    for (&faces, 0..) |*face, i| {
        try ctx.render(.{
            .@"3d" = .{
                .polygon = .{
                    .vertices = &cube,
                    .source = .{ .color = colors[i] },
                    .indices = face,
                    .view = view,
                    .model = model,
                },
            },
        });
    }

    var snap = try surface.snapshot();
    defer snap.destroy();

    const buffer = try std.testing.allocator.alloc(u8, 1024 * snap.img.imageByteSize());
    defer std.testing.allocator.free(buffer);

    const buffer_hash = std.zig.hashSrc(try snap.img.writeToMemory(buffer, .{ .png = .{} }));

    try std.testing.expectEqualSlices(u8, &[_]u8{
        0x75, 0xAB, 0xE9, 0xA6, 0xA7, 0xB5, 0xF8, 0xC0, 0x83, 0x5D, 0xE2, 0x9F, 0xEA, 0x12, 0x13, 0xB3,
    }, &buffer_hash);
}
