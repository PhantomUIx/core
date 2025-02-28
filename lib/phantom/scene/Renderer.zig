const std = @import("std");
const assert = std.debug.assert;
const math = @import("../math.zig");
const scene = @import("../scene.zig");
const Renderer = @This();

pub const Canvas = @import("Renderer/Canvas.zig");
pub const Html = @import("Renderer/Html.zig");

pub const VTable = struct {
    render: *const fn (self: *anyopaque, node: scene.Node) anyerror!void,
    destroy: *const fn (self: *anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn render(self: *const Renderer, node: scene.Node) anyerror!void {
    return self.vtable.render(self.ptr, node);
}

pub inline fn destroy(self: *const Renderer) void {
    return self.vtable.destroy(self.ptr);
}

test {
    _ = Canvas;
    _ = Html;
}
