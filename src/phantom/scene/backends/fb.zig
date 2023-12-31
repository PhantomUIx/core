const vizops = @import("vizops");
const painting = @import("../../painting.zig");

pub const Scene = @import("fb/scene.zig");

pub const NodeArc = @import("../nodes/arc.zig").NodeArc(struct {
    const Self = @This();
    pub const Scene = @import("fb/scene.zig");

    pub fn frame(self: *NodeArc, scene: *Self.Scene) anyerror!void {
        const size = (try self.node.state(scene.base.frameInfo())).size;
        const pos: vizops.vector.UsizeVector2 = if (scene.base.subscene) |sub| sub.pos else .{};

        try painting.Canvas.init(scene.buffer, .{
            .size = size,
            .pos = pos,
        }).fillArc(vizops.vector.UsizeVector2.zero(), size, @intFromFloat(self.options.radius * @as(f32, 360.0)), self.options.color);
    }
});

pub const NodeFrameBuffer = @import("../nodes/fb.zig").NodeFb(struct {
    const Self = @This();
    pub const Scene = @import("fb/scene.zig");

    pub fn frame(self: *NodeFrameBuffer, scene: *Self.Scene) anyerror!void {
        const size = (try self.node.state(scene.base.frameInfo())).size;
        const pos: vizops.vector.UsizeVector2 = if (scene.base.subscene) |sub| sub.pos else .{};

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

    pub fn frame(self: *NodeRect, scene: *Self.Scene) anyerror!void {
        const size = (try self.node.state(scene.base.frameInfo())).size;
        const pos: vizops.vector.UsizeVector2 = if (scene.base.subscene) |sub| sub.pos else .{};

        try painting.Canvas.init(scene.buffer, .{
            .size = size,
            .pos = pos,
        }).fillRect(vizops.vector.UsizeVector2.zero(), size, @intFromFloat((self.options.radius orelse @as(f32, 0.0)) * @as(f32, 360.0)), self.options.color);
    }
});
