const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");
const phantom = @import("phantom");
const vizops = @import("vizops");

const displayBackendType: phantom.display.BackendType = @enumFromInt(@intFromEnum(options.display_backend));
const displayBackend = phantom.display.Backend(displayBackendType);

const sceneBackendType: phantom.scene.BackendType = @enumFromInt(@intFromEnum(options.scene_backend));
const sceneBackend = phantom.scene.Backend(sceneBackendType);

pub fn main() !void {
    const alloc = if (builtin.link_libc) std.heap.c_allocator else std.heap.page_allocator;

    var display = displayBackend.Display.init(alloc, .client);
    defer display.deinit();

    if (displayBackendType == .headless) {
        _ = try display.addOutput(.{
            .enable = true,
            .size = .{
                .phys = vizops.vector.Float32Vector2.init([_]f32{ 306, 229.5 }),
                .res = vizops.vector.UsizeVector2.init([_]usize{ 1024, 768 }),
            },
            .scale = vizops.vector.Float32Vector2.init(1.0),
            .name = "display-0",
            .manufacturer = "PhantomUI",
            .colorFormat = try vizops.color.fourcc.Value.decode(vizops.color.fourcc.formats.argb16161616),
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
        .size = vizops.vector.UsizeVector2.init(64),
    });
    defer {
        surface.destroy() catch @panic("Failed to destroy the surface");
        surface.deinit();
    }

    const scene = try surface.createScene(sceneBackendType);

    const flex = try scene.createNode(.NodeFlex, .{
        .direction = phantom.painting.Axis.horizontal,
        .children = [_]*phantom.scene.Node{
            try scene.createNode(.NodeArc, .{
                .radius = @as(f32, 32.0),
                .angles = vizops.vector.Float32Vector2.init([_]f32{ 0, std.math.tau - 0.0001 }),
                .color = vizops.color.Any{
                    .float32 = .{
                        .sRGB = .{
                            .value = .{ 1.0, 0.0, 0.0, 1.0 },
                        },
                    },
                },
            }),
            try scene.createNode(.NodeRect, .{
                .color = vizops.color.Any{
                    .float32 = .{
                        .sRGB = .{
                            .value = .{ 0.0, 1.0, 0.0, 1.0 },
                        },
                    },
                },
                .size = vizops.vector.Float32Vector2.init([_]f32{ 10.0, 10.0 }),
            }),
        },
    });
    defer flex.deinit();

    while (true) {
        const seq = scene.seq;
        _ = try scene.frame(flex);
        if (seq != scene.seq) std.debug.print("Frame #{}\n", .{scene.seq});
    }
}
