pub const Scene = @import("headless/scene.zig");

pub const NodeArc = @import("../nodes/arc.zig").NodeArc(struct {});
pub const NodeFrameBuffer = @import("../nodes/fb.zig").NodeFb(struct {});
pub const NodeRect = @import("../nodes/rect.zig").NodeRect(struct {});
pub const NodeText = @import("../nodes/text.zig").NodeText(struct {});
