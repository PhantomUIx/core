const std = @import("std");
const Allocator = std.mem.Allocator;
const graphics = @import("../../graphics.zig");
const math = @import("../../math.zig");
const SceneNode = @import("../../scene.zig").Node;
const Renderer = @import("../Renderer.zig");
const Self = @This();

allocator: std.mem.Allocator,
base: Renderer,
context: *graphics.Context,

const vtable: Renderer.VTable = .{
    .render = vtable_render,
    .destroy = vtable_destroy,
};

pub fn create(alloc: Allocator, context: *graphics.Context) Allocator.Error!*Renderer {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .base = .{
            .ptr = self,
            .vtable = &vtable,
        },
        .context = context,
    };
    return &self.base;
}

fn renderChild(self: *Self, node: SceneNode, offset: math.Vec2(f32)) !void {
    const ctx = self.context.as(.@"2d");

    switch (node) {
        .container => |container| {
            const pos = offset.add(container.layout.position orelse math.Vec2(f32).zero);
            const size = container.layout.size orelse math.Vec2(f32).zero;

            try ctx.render(.{
                .rect = .{
                    .source = .{ .color = container.style.background_color orelse graphics.Color.black },
                    .border_radius = container.style.border_radius orelse .{},
                    .rect = math.Rect(f32).init(pos.value, size.value),
                    .mode = .fill,
                },
            });

            for (container.children) |child| {
                try self.renderChild(child, pos);
            }
        },
        .image => |image| {
            try ctx.render(.{
                .composite = .{
                    .source = image.source,
                    .position = offset,
                    .mode = .over,
                },
            });
        },
        else => return error.Unsupported,
    }
}

pub fn render(self: *Self, node: SceneNode) anyerror!void {
    try self.renderChild(node, math.Vec2(f32).zero);
}

pub fn destroy(self: *Self) void {
    self.allocator.destroy(self);
}

fn vtable_render(ptr: *anyopaque, node: SceneNode) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.render(node);
}

fn vtable_destroy(ptr: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.destroy();
}

test {
    const surface = try graphics.backend.z2d.Surface.create(std.testing.allocator, .rgba32, 100, 100);
    defer surface.destroy();

    const context = try surface.getContext(.@"2d");
    defer context.destroy();

    const renderer = try create(std.testing.allocator, context);
    defer renderer.destroy();

    try renderer.render(.{
        .container = .{
            .style = .{
                .background_color = graphics.Color.init(.{ 0.14, 0.15, 0.23, 1.0 }),
                .foreground_color = graphics.Color.init(.{ 0.0, 0.0, 0.0, 1.0 }),
            },
            .layout = .{
                .size = .{ .value = .{ 100, 100 } },
            },
            .children = &.{},
        },
    });

    var snap = try surface.snapshot();
    defer snap.destroy();

    // TODO: figure out how to compare the output to what's expected.
    // For now, we have to manually verify this.

    var tmpdir = std.testing.tmpDir(.{});
    defer tmpdir.cleanup();

    var file = try tmpdir.dir.createFile("snapshot.png", .{});
    defer file.close();

    try snap.img.writeToFile(file, .{
        .png = .{},
    });
}
