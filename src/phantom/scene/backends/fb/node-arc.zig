pub const NodeArc = @import("../../nodes/arc.zig").NodeArc(struct {
    pub const Scene = @import("scene.zig");

    pub fn frame(self: *NodeArc, scene: *Scene) anyerror!void {
        _ = self;
        _ = scene;
    }
});
