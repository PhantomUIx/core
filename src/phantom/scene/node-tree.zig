const std = @import("std");
const vizops = @import("vizops");
const Node = @import("node.zig");
const NodeTree = @This();

pub const Child = struct {
    node: *Node,
    pos: vizops.vector.Float32Vector,
};

children: std.ArrayList(Child),

pub fn node(self: *NodeTree) *Node {
    return .{
        .ptr = self,
        .vtable = &.{
            .state = state,
            .preFrame = preFrame,
            .frame = frame,
            .postFrame = postFrame,
            .deinit = deinit,
        },
    };
}

fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) Node.State {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    var size = vizops.vector.Vector2(usize).zero();

    for (self.children.items) |child| {
        const cstate = child.node.state(frameInfo.child(frameInfo.size.avail.sub(size)));

        size.set(0, std.math.max(size.get(0), child.pos.get(0) + cstate.size.get(0)));
        size.set(1, std.math.max(size.get(1), child.pos.get(1) + cstate.size.get(1)));
    }

    return .{
        .size = size,
        .pos = vizops.vector.Vector2(usize).zero(),
        .frameInfo = frameInfo,
    };
}

fn preFrame(ctx: *anyopaque, frameInfo: Node.FrameInfo) Node.State {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    var size = vizops.vector.Vector2(usize).zero();

    for (self.children.items) |child| {
        const cstate = child.node.preFrame(frameInfo.child(frameInfo.size.avail.sub(size)));

        size.set(0, std.math.max(size.get(0), child.pos.get(0) + cstate.size.get(0)));
        size.set(1, std.math.max(size.get(1), child.pos.get(1) + cstate.size.get(1)));
    }

    return .{
        .size = size,
        .pos = vizops.vector.Vector2(usize).zero(),
        .frameInfo = frameInfo,
    };
}

fn frame(ctx: *anyopaque) void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));

    for (self.children.items) |child| child.node.frame();
}

fn postFrame(ctx: *anyopaque) void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));

    for (self.children.items) |child| child.node.postFrame();
}

fn deinit(ctx: *anyopaque) void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));

    for (self.children.items) |child| child.node.deinit();
    self.children.deinit();
}
