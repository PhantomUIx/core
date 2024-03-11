const std = @import("std");
const Allocator = std.mem.Allocator;
const anyplus = @import("any+");
const Scene = @import("../../base.zig");
const Node = @import("../../node.zig");
const Fb = @import("../../../painting/fb/base.zig");
const FbScene = @This();

frame_info: Node.FrameInfo,
target: Scene.Target,
buffer: *Fb,
base: Scene,

pub fn new(options: Scene.Options) !*FbScene {
    const alloc = options.allocator;
    const target = if (options.target) |target| target else return error.BadTarget;

    const buffer = switch (target) {
        .surface => |surf| blk: {
            const info = try surf.info();
            break :blk try surf.device.createFrameBuffer(.{
                .res = info.size,
                .colorspace = info.colorspace,
                .colorFormat = info.colorFormat,
            });
        },
        .fb => |fb| try fb.dupe(),
        else => return error.BadTarget,
    };
    errdefer buffer.deinit();

    const self = try alloc.create(FbScene);
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
                .preFrame = preFrame,
                .postFrame = postFrame,
            },
            .subscene = null,
            .type = .fb,
        },
        .buffer = buffer,
        .target = target,
    };
    return self;
}

fn frameInfo(ctx: *anyopaque) Node.FrameInfo {
    const self: *FbScene = @ptrCast(@alignCast(ctx));
    return self.frame_info;
}

fn deinit(ctx: *anyopaque) void {
    const self: *FbScene = @ptrCast(@alignCast(ctx));
    self.buffer.deinit();
    self.target.deinit();
    self.base.allocator.destroy(self);
}

fn preFrame(ctx: *anyopaque, _: *Node) anyerror!void {
    const self: *FbScene = @ptrCast(@alignCast(ctx));
    return self.buffer.lock();
}

fn postFrame(ctx: *anyopaque, _: *Node, didWork: bool) anyerror!void {
    const self: *FbScene = @ptrCast(@alignCast(ctx));
    defer self.buffer.unlock();

    if (didWork) {
        try self.buffer.commit();

        if (self.target == .fb) {
            if (try self.target.fb.addr() == try self.buffer.addr()) {
                try self.target.fb.commit();
                return;
            }
        }

        try switch (self.target) {
            .surface => |s| s.blt(.from, self.buffer, .{}),
            .fb => |f| f.blt(.from, self.buffer, .{}),
            else => unreachable,
        };
    }

    try switch (self.target) {
        .surface => {},
        .fb => |f| f.commit(),
        else => unreachable,
    };
}
