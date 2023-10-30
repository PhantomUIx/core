const std = @import("std");
const options = @import("options");
const phantom = @import("phantom");
const vizops = @import("vizops");

const backendType: phantom.scene.BackendType = @enumFromInt(@intFromEnum(options.backend));
const backend = phantom.scene.Backend(backendType);

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var scene = backend.Scene.init(.{
        .frame_info = phantom.scene.Node.FrameInfo.init(.{
            .res = vizops.vector.Vector2(usize).init(.{ 1024, 768 }),
            .scale = vizops.vector.Float32Vector2.init(.{ 1.0, 1.0 }),
            .depth = 24,
        }),
    });

    var tree = try phantom.scene.NodeTree.new(alloc);
    defer tree.node.deinit();

    try tree.children.append(.{
        .node = @constCast(&(try backend.NodeCircle.new(alloc, .{
            .radius = 32.0,
            .color = vizops.vector.Float32Vector4.init(.{ 1.0, 0.0, 0.0, 1.0 }),
        })).node),
        .pos = vizops.vector.Float32Vector2.init(.{ 0.0, 0.0 }),
    });

    _ = try @constCast(&scene.scene()).frame(@constCast(&tree.node));

    const availSize = @constCast(&scene.scene()).frameInfo().size.res.sub(tree.node.last_state.?.size);

    std.debug.print("Scene has {} horizontal pixels and {} vertical pixels left over\n", .{ availSize.value[0], availSize.value[1] });
}
