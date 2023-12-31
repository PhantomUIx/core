const vizops = @import("vizops");

pub const NodeFb = @import("../../nodes/fb.zig").NodeFb(struct {
    pub const Scene = @import("scene.zig");

    pub fn frame(self: *NodeFb, scene: *Scene) anyerror!void {
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
