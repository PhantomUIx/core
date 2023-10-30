const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const Scene = @import("base.zig");
const Node = @import("node.zig");
const NodeTree = @This();

pub const Child = struct {
    node: *Node,
    pos: vizops.vector.Float32Vector,
};

children: std.ArrayList(Child),
node: Node,

pub fn new(alloc: Allocator) Allocator.Error!*NodeTree {
    const self = try alloc.create(NodeTree);
    self.* = .{
        .children = std.ArrayList(Child).init(alloc),
        .node = .{
            .ptr = self,
            .vtable = &.{
                .state = state,
                .preFrame = preFrame,
                .frame = frame,
                .postFrame = postFrame,
                .deinit = deinit,
            },
        },
    };
    return self;
}

fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) Node.State {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    var size = vizops.vector.Vector2(usize).zero();

    for (self.children.items) |child| {
        const cstate = child.node.state(frameInfo.child(frameInfo.size.avail.sub(size)));
        const pos = vizops.vector.Vector2(usize).init(.{
            @intCast(child.pos.get(0) * frameInfo.size.res.get(0) / 100.0),
            @intCast(child.pos.get(1) * frameInfo.size.res.get(1) / 100.0),
        });

        size.set(0, std.math.max(size.get(0), pos.get(0) + cstate.size.get(0)));
        size.set(1, std.math.max(size.get(1), pos.get(1) + cstate.size.get(1)));
    }

    return .{
        .size = size,
        .pos = vizops.vector.Vector2(usize).zero(),
        .frameInfo = frameInfo,
    };
}

fn preFrame(ctx: *anyopaque, frameInfo: Node.FrameInfo, scene: *Scene) Node.State {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    var size = vizops.vector.Vector2(usize).zero();

    for (self.children.items) |child| {
        const cstate = child.node.preFrame(frameInfo.child(frameInfo.size.avail.sub(size)), scene);
        const pos = vizops.vector.Vector2(usize).init(.{
            @intCast(child.pos.get(0) * frameInfo.size.res.get(0) / 100.0),
            @intCast(child.pos.get(1) * frameInfo.size.res.get(1) / 100.0),
        });

        size.set(0, std.math.max(size.get(0), pos.get(0) + cstate.size.get(0)));
        size.set(1, std.math.max(size.get(1), pos.get(1) + cstate.size.get(1)));
    }

    return .{
        .size = size,
        .pos = vizops.vector.Vector2(usize).zero(),
        .frame_info = frameInfo,
    };
}

fn frame(ctx: *anyopaque, scene: *Scene) void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const frameInfo = self.node.last_state.?.frame_info;

    // TODO: figure out how to tell scene to move to where the child is at
    for (self.children.items) |child| {
        const pos = vizops.vector.Vector2(usize).init(.{
            @intCast(child.pos.get(0) * frameInfo.size.res.get(0) / 100.0),
            @intCast(child.pos.get(1) * frameInfo.size.res.get(1) / 100.0),
        });

        child.node.frame(&scene.sub(pos, child.node.last_state.?.size));
    }
}

fn postFrame(ctx: *anyopaque, scene: *Scene) void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const frameInfo = self.node.last_state.?.frame_info;

    // TODO: figure out how to tell scene to move to where the child is at
    for (self.children.items) |child| {
        const pos = vizops.vector.Vector2(usize).init(.{
            @intCast(child.pos.get(0) * frameInfo.size.res.get(0) / 100.0),
            @intCast(child.pos.get(1) * frameInfo.size.res.get(1) / 100.0),
        });

        child.node.postFrame(&scene.sub(pos, child.node.last_state.?.size));
    }
}

fn deinit(ctx: *anyopaque) void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const alloc = self.children.allocator;

    for (self.children.items) |child| child.node.deinit();
    self.children.deinit();
    alloc.destroy(self);
}
