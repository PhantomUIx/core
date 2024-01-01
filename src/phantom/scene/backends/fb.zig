const std = @import("std");
const vizops = @import("vizops");
const math = @import("../../math.zig");
const painting = @import("../../painting.zig");
const BaseScene = @import("../base.zig");

pub const Scene = @import("fb/scene.zig");

pub const NodeArc = @import("../nodes/arc.zig").NodeArc(struct {
    const Self = @This();
    pub const Scene = @import("fb/scene.zig");

    pub fn frame(self: *NodeArc, scene: *Self.Scene, subscene: ?BaseScene.Sub) anyerror!void {
        const size = (try self.node.state(scene.base.frameInfo())).size;
        const pos: vizops.vector.UsizeVector2 = if (subscene) |sub| sub.pos else .{};

        const bufferInfo = scene.buffer.info();
        const buffer = try self.node.allocator.alloc(u8, @divExact(bufferInfo.colorFormat.width(), 8));
        defer self.node.allocator.free(buffer);
        try vizops.color.writeAnyBuffer(bufferInfo.colorFormat, buffer, self.options.color);

        try painting.Canvas.init(scene.buffer, .{
            .size = size,
            .pos = pos,
        }).arc(vizops.vector.UsizeVector2.init([_]usize{std.math.lossyCast(f32, self.options.radius)}), self.options.angles, self.options.radius, buffer);
    }
});

pub const NodeFrameBuffer = @import("../nodes/fb.zig").NodeFb(struct {
    const Self = @This();
    pub const Scene = @import("fb/scene.zig");

    pub fn frame(self: *NodeFrameBuffer, scene: *Self.Scene, subscene: ?BaseScene.Sub) anyerror!void {
        const size = (try self.node.state(scene.base.frameInfo())).size;
        const pos: vizops.vector.UsizeVector2 = if (subscene) |sub| sub.pos else .{};

        try self.options.source.blt(.to, scene.buffer, .{
            .sourceOffset = self.options.offset,
            .destOffset = pos,
            .size = size,
            .blend = self.options.blend,
        });
    }
});

pub const NodeRect = @import("../nodes/rect.zig").NodeRect(struct {
    const Self = @This();
    pub const Scene = @import("fb/scene.zig");

    pub fn frame(self: *NodeRect, scene: *Self.Scene, subscene: ?BaseScene.Sub) anyerror!void {
        const size = (try self.node.state(scene.base.frameInfo())).size;
        const pos: vizops.vector.UsizeVector2 = if (subscene) |sub| sub.pos else .{};

        const bufferInfo = scene.buffer.info();
        const buffer = try self.node.allocator.alloc(u8, @divExact(bufferInfo.colorFormat.width(), 8));
        defer self.node.allocator.free(buffer);
        try vizops.color.writeAnyBuffer(bufferInfo.colorFormat, buffer, self.options.color);

        const radius = self.options.radius orelse painting.Radius(f32){};

        try painting.Canvas.init(scene.buffer, .{
            .size = size,
            .pos = pos,
        }).rect(vizops.vector.UsizeVector2.zero(), size, radius, buffer);
    }
});
