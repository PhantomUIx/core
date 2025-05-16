pub const display = @import("phantom/display.zig");
pub const fonts = @import("phantom/fonts.zig");
pub const gpu = @import("phantom/gpu.zig");
pub const graphics = @import("phantom/graphics.zig");
pub const math = @import("phantom/math.zig");
pub const scene = @import("phantom/scene.zig");
pub const widgets = @import("phantom/widgets.zig");

test {
    _ = display;
    _ = fonts;
    _ = gpu;
    _ = graphics;
    _ = math;
    _ = scene;
    _ = widgets;
}
