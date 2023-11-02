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
            .physicalSize = vizops.vector.Float32Vector2.init(.{ 306, 229.5 }),
            .depth = 24,
        }),
    });

    var flex = try phantom.scene.NodeFlex.new(alloc, .horizontal);
    defer flex.tree.node.deinit();

    try flex.children.append(@constCast(&(try backend.NodeCircle.new(alloc, .{
        .radius = 32.0,
        .color = vizops.vector.Float32Vector4.init(.{ 1.0, 0.0, 0.0, 1.0 }),
    })).node));

    _ = try @constCast(&scene.scene()).frame(@constCast(&flex.tree.node));

    const availSize = @constCast(&scene.scene()).frameInfo().size.res.sub(flex.tree.node.last_state.?.size);

    std.debug.print("Scene has {} horizontal pixels and {} vertical pixels left over\n", .{ availSize.value[0], availSize.value[1] });

    const inch = phantom.math.inches(@constCast(&scene.scene()).frameInfo(), vizops.vector.Float32Vector2.init(.{ 1, 1 }));
    std.debug.print("One inch on the display takes up {}x{}\n", .{ inch.value[0], inch.value[1] });

    const availSizeInches = availSize.div(inch);
    std.debug.print("Scene has {}x{} inches available\n", .{ availSizeInches.value[0], availSizeInches.value[1] });
}
