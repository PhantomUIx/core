const math = @import("../math.zig");
const graphics = @import("../graphics.zig");

pub const Layout = struct {
    position: ?math.Vec2(f32) = null,
    size: ?math.Vec2(f32) = null,
};

pub const Style = struct {
    background_color: ?graphics.Color = null,
    foreground_color: ?graphics.Color = null,
    border_radius: ?graphics.Context.@"2d".Operation.Rect.BorderRadius = null,
};
