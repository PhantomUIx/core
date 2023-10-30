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

const ChildState = struct {
    state: Node.State,
    pos: vizops.vector.Vector2(usize),

    pub fn equal(self: ChildState, other: ChildState) bool {
        return std.simd.countTrues(@Vector(2, bool){
            self.state.equal(other.state),
            std.simd.countTrues(self.pos.value == other.pos.value) == 2,
        }) == 2;
    }

    pub inline fn deinit(self: ChildState, alloc: ?Allocator) void {
        return self.state.deinit(alloc);
    }
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
                .dupe = dupe,
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

fn stateEqual(ctx: *anyopaque, otherctx: *anyopaque) bool {
    const states: []ChildState = @ptrCast(@alignCast(ctx));
    const otherStates: []ChildState = @ptrCast(@alignCast(otherctx));

    if (states.len == otherStates.len) {
        for (states, otherStates) |s, os| {
            if (!s.equal(os)) return false;
        }
        return true;
    }
    return false;
}

fn stateFree(ctx: *anyopaque, alloc: std.mem.Allocator) void {
    const states: []ChildState = @ptrCast(@alignCast(ctx));

    for (states) |s| s.deinit(alloc);
    alloc.free(states);
}

fn dupe(ctx: *anyopaque) anyerror!*anyopaque {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const d = try self.children.allocator.create(NodeTree);
    errdefer d.deinit();

    d.* = .{
        .children = try std.ArrayList(Child).initCapacity(self.children.allocator, self.children.items.len),
        .node = .{
            .ptr = d,
            .vtable = self.node.vtable,
        },
    };
    errdefer d.children.deinit();

    for (self.children.items) |child| {
        const dchild = try child.dupe();
        d.children.appendAssumeCapacity(dchild);
        errdefer dchild.deinit();
    }
    return d;
}

fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!Node.State {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    var size = vizops.vector.Vector2(usize).zero();
    var states = try std.ArrayList(ChildState).initCapacity(self.children.allocator, self.children.items.len);

    for (self.children.items) |child| {
        const cstate = try child.node.state(frameInfo.child(frameInfo.size.avail.sub(size)));
        const pos = vizops.vector.Vector2(usize).init(.{
            @intCast(child.pos.get(0) * frameInfo.size.res.get(0) / 100.0),
            @intCast(child.pos.get(1) * frameInfo.size.res.get(1) / 100.0),
        });

        size.set(0, std.math.max(size.get(0), pos.get(0) + cstate.size.get(0)));
        size.set(1, std.math.max(size.get(1), pos.get(1) + cstate.size.get(1)));

        states.appendAssumeCapacity(.{
            .state = cstate,
            .pos = pos,
        });
    }

    return .{
        .size = size,
        .pos = vizops.vector.Vector2(usize).zero(),
        .frameInfo = frameInfo,
        .allocator = self.children.allocator,
        .ptr = states.items,
        .ptrEqual = stateEqual,
        .ptrFree = stateFree,
    };
}

fn preFrame(ctx: *anyopaque, frameInfo: Node.FrameInfo, scene: *Scene) anyerror!Node.State {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    var size = vizops.vector.Vector2(usize).zero();
    var states = try std.ArrayList(ChildState).initCapacity(self.children.allocator, self.children.items.len);

    for (self.children.items) |child| {
        const cstate = try child.node.preFrame(frameInfo.child(frameInfo.size.avail.sub(size)), scene);
        const pos = vizops.vector.Vector2(usize).init(.{
            @intCast(child.pos.get(0) * frameInfo.size.res.get(0) / 100.0),
            @intCast(child.pos.get(1) * frameInfo.size.res.get(1) / 100.0),
        });

        size.set(0, std.math.max(size.get(0), pos.get(0) + cstate.size.get(0)));
        size.set(1, std.math.max(size.get(1), pos.get(1) + cstate.size.get(1)));

        states.appendAssumeCapacity(.{
            .state = cstate,
            .pos = pos,
        });
    }

    return .{
        .size = size,
        .pos = vizops.vector.Vector2(usize).zero(),
        .frame_info = frameInfo,
        .allocator = self.children.allocator,
        .ptr = states.items,
        .ptrEqual = stateEqual,
        .ptrFree = stateFree,
    };
}

fn frame(ctx: *anyopaque, scene: *Scene) anyerror!void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const frameInfo = self.node.last_state.?.frame_info;

    for (self.children.items) |child| {
        const pos = vizops.vector.Vector2(usize).init(.{
            @intCast(child.pos.get(0) * frameInfo.size.res.get(0) / 100.0),
            @intCast(child.pos.get(1) * frameInfo.size.res.get(1) / 100.0),
        });

        try child.node.frame(&scene.sub(pos, child.node.last_state.?.size));
    }
}

fn postFrame(ctx: *anyopaque, scene: *Scene) anyerror!void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const frameInfo = self.node.last_state.?.frame_info;

    for (self.children.items) |child| {
        const pos = vizops.vector.Vector2(usize).init(.{
            @intCast(child.pos.get(0) * frameInfo.size.res.get(0) / 100.0),
            @intCast(child.pos.get(1) * frameInfo.size.res.get(1) / 100.0),
        });

        try child.node.postFrame(&scene.sub(pos, child.node.last_state.?.size));
    }
}

fn deinit(ctx: *anyopaque) void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const alloc = self.children.allocator;

    for (self.children.items) |child| child.node.deinit();
    self.children.deinit();
    alloc.destroy(self);
}
