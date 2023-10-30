const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const Scene = @import("../../base.zig");
const Node = @import("../../node.zig");
const NodeCircle = @This();

pub const Options = struct {
    radius: f32,
};

allocator: Allocator,
options: Options,
node: Node,

pub fn new(alloc: Allocator, options: Options) Allocator.Error!*NodeCircle {
    const self = try alloc.create(NodeCircle);
    self.* = .{
        .allocator = alloc,
        .options = options,
        .node = .{
            .ptr = self,
            .vtable = &.{
                .dupe = dupe,
                .state = state,
                .preFrame = preFrame,
                .frame = frame,
                .deinit = deinit,
            },
        },
    };
    return self;
}

fn dupe(ctx: *anyopaque) anyerror!*anyopaque {
    const self: *NodeCircle = @ptrCast(@alignCast(ctx));
    return try new(self.allocator, self.options);
}

fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!Node.State {
    const self: *NodeCircle = @ptrCast(@alignCast(ctx));
    const size = 2 * self.options.radius;
    return .{
        .size = vizops.vector.Vector2(usize).init(.{
            @intFromFloat(size * frameInfo.scale.value[0] * @as(f32, @floatFromInt(frameInfo.size.res.value[0])) / 100.0),
            @intFromFloat(size * frameInfo.scale.value[1] * @as(f32, @floatFromInt(frameInfo.size.res.value[1])) / 100.0),
        }),
        .frame_info = frameInfo,
        .allocator = self.allocator,
    };
}

fn preFrame(ctx: *anyopaque, frameInfo: Node.FrameInfo, _: *Scene) anyerror!Node.State {
    const self: *NodeCircle = @ptrCast(@alignCast(ctx));
    const size = 2 * self.options.radius;
    return .{
        .size = vizops.vector.Vector2(usize).init(.{
            @intFromFloat(size * frameInfo.scale.value[0] * @as(f32, @floatFromInt(frameInfo.size.res.value[0])) / 100.0),
            @intFromFloat(size * frameInfo.scale.value[1] * @as(f32, @floatFromInt(frameInfo.size.res.value[1])) / 100.0),
        }),
        .frame_info = frameInfo,
        .allocator = self.allocator,
    };
}

fn frame(ctx: *anyopaque, _: *Scene) anyerror!void {
    const self: *NodeCircle = @ptrCast(@alignCast(ctx));
    _ = self;
}

fn deinit(ctx: *anyopaque) void {
    const self: *NodeCircle = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}
