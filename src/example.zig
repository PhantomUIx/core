const std = @import("std");
const phantom = @import("phantom");
const vizops = @import("vizops");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var scene = phantom.scene.backends.headless.Scene{
        .frame_info = phantom.scene.Node.FrameInfo.init(.{
            .res = vizops.vector.Vector2(usize).init(.{ 1024, 768 }),
            .scale = vizops.vector.Float32Vector2.init(.{ 1.0, 1.0 }),
            .depth = 24,
        }),
    };

    var tree = try phantom.scene.NodeTree.new(alloc);
    defer tree.node.deinit();

    _ = try @constCast(&scene.scene()).frame(@constCast(&tree.node));

    std.debug.print("{}\n{}\n{}\n", .{ scene, tree, phantom.scene.BackendType });
}
