const std = @import("std");
const Allocator = std.mem.Allocator;
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
                .createNode = createNode,
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
    self.base.allocator.destroy(self);
}

fn createNode(ctx: *anyopaque, typeName: []const u8, args: std.StringHashMap(?*anyopaque)) anyerror!*Node {
    _ = ctx;
    return @import("../../../scene.zig").createNode(.headless, typeName, args);
}
