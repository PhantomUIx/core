const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const Base = @import("../../base.zig");
const Surface = @import("../../surface.zig");
const Scene = @import("../../../scene/base.zig");
const Node = @import("../../../scene/node.zig");
const HeadlessScene = @import("../../../scene/backends/headless/scene.zig");
const HeadlessOutput = @import("output.zig");
const HeadlessSurface = @This();

base: Surface,
allocator: Allocator,
info: Surface.Info,
scene: ?*HeadlessScene,
output: ?*HeadlessOutput,
id: ?usize,

pub fn new(alloc: Allocator, displayKind: Base.Kind, kind: Surface.Kind, info: Surface.Info) Allocator.Error!*HeadlessSurface {
    const self = try alloc.create(HeadlessSurface);
    errdefer alloc.destroy(self);

    self.* = .{
        .base = .{
            .ptr = self,
            .vtable = &.{
                .deinit = impl_deinit,
                .destroy = impl_destroy,
                .info = impl_info,
                .updateInfo = impl_update_info,
                .createScene = impl_create_scene,
            },
            .kind = kind,
            .displayKind = displayKind,
            .type = @typeName(HeadlessSurface),
        },
        .allocator = alloc,
        .info = info,
        .scene = null,
        .output = null,
        .id = null,
    };
    return self;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *HeadlessSurface = @ptrCast(@alignCast(ctx));

    if (self.scene) |scene| scene.base.deinit();

    self.allocator.destroy(self);
}

fn impl_destroy(ctx: *anyopaque) anyerror!void {
    const self: *HeadlessSurface = @ptrCast(@alignCast(ctx));
    if (self.output) |output| {
        if (self.id) |id| {
            _ = output.surfaces.swapRemove(id);
        }
    }
}

fn impl_info(ctx: *anyopaque) anyerror!Surface.Info {
    const self: *HeadlessSurface = @ptrCast(@alignCast(ctx));
    return self.info;
}

fn impl_update_info(ctx: *anyopaque, info: Surface.Info, fields: []std.meta.FieldEnum(Surface.Info)) anyerror!void {
    _ = ctx;
    _ = info;
    _ = fields;
    return error.NotImplemented;
}

fn impl_create_scene(ctx: *anyopaque) anyerror!*Scene {
    const self: *HeadlessSurface = @ptrCast(@alignCast(ctx));

    if (self.scene) |scene| return @constCast(&scene.base);

    if (self.output) |output| {
        const outputInfo = try output.base.info();

        self.scene = try HeadlessScene.new(self.allocator, .{
            .frame_info = Node.FrameInfo.init(.{
                .res = self.info.size,
                .scale = outputInfo.scale,
                .depth = self.info.depth orelse outputInfo.depth,
            }),
        });
        return @constCast(&self.scene.?.base);
    }
    return error.MissingOutput;
}
