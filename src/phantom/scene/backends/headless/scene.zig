const std = @import("std");
const Allocator = std.mem.Allocator;
const anyplus = @import("any+");
const Scene = @import("../../base.zig");
const Node = @import("../../node.zig");
const HeadlessScene = @This();

frame_info: Node.FrameInfo,
base: Scene,

pub fn new(options: Scene.Options) Allocator.Error!*HeadlessScene {
    const alloc = options.allocator;
    const self = try alloc.create(HeadlessScene);
    errdefer alloc.destroy(self);

    self.* = .{
        .frame_info = options.frame_info,
        .base = .{
            .allocator = alloc,
            .ptr = self,
            .vtable = &.{
                .sub = null,
                .frameInfo = frameInfo,
                .deinit = deinit,
            },
            .subscene = null,
            .type = .headless,
        },
    };
    return self;
}

fn frameInfo(ctx: *anyopaque) Node.FrameInfo {
    const self: *HeadlessScene = @ptrCast(@alignCast(ctx));
    return self.frame_info;
}

fn deinit(ctx: *anyopaque) void {
    const self: *HeadlessScene = @ptrCast(@alignCast(ctx));
    self.base.allocator.destroy(self);
}
