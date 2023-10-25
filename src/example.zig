const std = @import("std");
const phantom = @import("phantom");
const vizops = @import("vizops");

const displaySize = vizops.Vector(2, usize).init(.{ 600, 400 });
const depth = 24;

const FrameBuffer = phantom.fb.Allocated(.{
    .size = displaySize,
    .depth = depth,
    .element = @Vector(3, f32),
});

const BaseCanvas = phantom.Canvas(.{
    .size = displaySize,
    .depth = depth,
});

pub fn main() !void {
    var fb = try FrameBuffer.init(std.heap.page_allocator);
    defer fb.deinit();

    const canvas = phantom.canvas.FrameBuffer(FrameBuffer.Base, BaseCanvas){
        .fb = fb.framebuffer(),
    };

    std.debug.print("{}\n", .{canvas});
}
