const std = @import("std");
const options = @import("options");
const phantom = @import("phantom");
const vizops = @import("vizops");

const displayBackendType: phantom.display.BackendType = @enumFromInt(@intFromEnum(options.display_backend));
const displayBackend = phantom.display.Backend(displayBackendType);

const sceneBackendType: phantom.scene.BackendType = @enumFromInt(@intFromEnum(options.scene_backend));
const sceneBackend = phantom.scene.Backend(sceneBackendType);

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var display = displayBackend.Display.init(alloc, .client);
    defer display.deinit();

    if (displayBackendType == .headless) {
        _ = try display.addOutput(.{
            .enable = true,
            .size = .{
                .phys = vizops.vector.Float32Vector2.init(.{ 306, 229.5 }),
                .res = vizops.vector.Vector2(usize).init(.{ 1024, 768 }),
            },
            .scale = vizops.vector.Float32Vector2.init(.{ 1.0, 1.0 }),
            .name = "display-0",
            .manufacturer = "PhantomUI",
            .depth = 24,
        });
    }

    const outputs = try @constCast(&display.display()).outputs();
    defer outputs.deinit();

    if (outputs.items.len == 0) {
        std.debug.print("No display outputs exist\n", .{});
        return error.NoOutputs;
    }

    const output = outputs.items[0];
    const surface = try output.createSurface(.view, .{
        .title = "Phantom UI Example",
        .toplevel = true,
        .states = &.{.mapped},
        .size = vizops.vector.Vector2(usize).init(.{ 64, 64 }),
    });
    defer {
        surface.destroy() catch @panic("Failed to destroy the surface");
        surface.deinit();
    }

    const scene = try surface.createScene(sceneBackendType);

    const flex = try scene.createNode(.NodeFlex, .{
        .direction = phantom.scene.Node.Axis.horizontal,
        .children = &[_]*phantom.scene.Node{
            try scene.createNode(.NodeCircle, .{
                .degree = 120,
                .color = vizops.vector.Float32Vector4.init(.{ 1.0, 0.0, 0.0, 1.0 }),
            }),
        },
    });
    defer flex.deinit();

    _ = try @constCast(scene).frame(flex);

    const availSize = @constCast(scene).frameInfo().size.res.sub(flex.last_state.?.size);

    std.debug.print("Scene has {} horizontal pixels and {} vertical pixels left over\n", .{ availSize.value[0], availSize.value[1] });
}
