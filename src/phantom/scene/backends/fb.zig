const vizops = @import("vizops");

pub const Scene = @import("fb/scene.zig");

pub const NodeArc = @import("../nodes/arc.zig").NodeArc(struct {
    const Self = @This();
    pub const Scene = @import("fb/scene.zig");

    pub fn frame(self: *NodeArc, scene: *Self.Scene) anyerror!void {
        _ = self;
        _ = scene;
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

        const bufferInfo = scene.buffer.info();

        const buffer = try self.node.allocator.alloc(u8, @divExact(bufferInfo.colorFormat.width(), 8));
        defer self.node.allocator.free(buffer);
        try vizops.color.writeAnyBuffer(bufferInfo.colorFormat, buffer, self.options.color);

        const stride = buffer.len * bufferInfo.res.value[0];

        var y: usize = 0;
        // TODO: handle corners
        while (y < size.value[1]) : (y += 1) {
            var x: usize = 0;
            while (x < size.value[0]) : (x += 1) {
                const i = ((y + pos.value[1]) * stride) + ((x + pos.value[0]) * buffer.len);
                try scene.buffer.write(i, buffer);
            }
        }
    }
});
