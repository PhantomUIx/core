const std = @import("std");
const Allocator = std.mem.Allocator;
const Scene = @import("../../base.zig");
const Node = @import("../../node.zig");
const HeadlessScene = @This();

pub const Options = struct {
    frame_info: Node.FrameInfo,
};

allocator: Allocator,
frame_info: Node.FrameInfo,
base: Scene,

pub fn new(alloc: Allocator, options: Options) Allocator.Error!*HeadlessScene {
    const self = try alloc.create(HeadlessScene);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .frame_info = options.frame_info,
        .base = .{
            .ptr = self,
            .vtable = &.{
                .sub = null,
                .frameInfo = frameInfo,
                .deinit = deinit,
            },
            .subscene = null,
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
    self.allocator.destroy(self);
}
