const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const math = @import("../math.zig");
const Scene = @import("base.zig");
const Node = @import("node.zig");
const NodeTree = @This();

pub const Child = struct {
    node: *Node,
    pos: vizops.vector.Float32Vector2,
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

const State = struct {
    children: std.ArrayList(ChildState),

    pub fn init(children: std.ArrayList(ChildState)) Allocator.Error!*State {
        const self = try children.allocator.create(State);
        self.* = .{
            .children = children,
        };
        return self;
    }

    pub fn equal(self: *State, other: *State) bool {
        if (self.children.items.len == other.children.items.len) {
            for (self.children.items, other.children.items) |s, o| {
                if (!s.equal(o)) return false;
            }
            return true;
        }
        return false;
    }

    pub fn deinit(self: *State) void {
        for (self.children.items) |s| s.deinit(self.children.allocator);
        self.children.allocator.destroy(self);
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
    const self: *State = @ptrCast(@alignCast(ctx));
    const other: *State = @ptrCast(@alignCast(otherctx));
    return self.equal(other);
}

fn stateFree(ctx: *anyopaque, _: std.mem.Allocator) void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.deinit();
}

fn dupe(ctx: *anyopaque) anyerror!*anyopaque {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const d = try self.children.allocator.create(NodeTree);
    errdefer self.children.allocator.destroy(d);

    d.* = .{
        .children = try std.ArrayList(Child).initCapacity(self.children.allocator, self.children.items.len),
        .node = .{
            .ptr = d,
            .vtable = self.node.vtable,
        },
    };
    errdefer d.children.deinit();

    for (self.children.items) |child| {
        const dchild = Child{
            .node = @ptrCast(@alignCast(try child.node.dupe())),
            .pos = child.pos,
        };

        d.children.appendAssumeCapacity(dchild);
        errdefer dchild.node.deinit();
    }
    return d;
}

fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!Node.State {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    var size = vizops.vector.Vector2(usize).zero();
    var states = try std.ArrayList(ChildState).initCapacity(self.children.allocator, self.children.items.len);

    for (self.children.items) |child| {
        const cstate = try child.node.state(frameInfo.child(frameInfo.size.avail.sub(size)));
        const pos = math.rel(frameInfo, child.pos);

        size.value[0] = @max(size.value[0], pos.value[0] + cstate.size.value[0]);
        size.value[1] = @max(size.value[1], pos.value[1] + cstate.size.value[1]);

        states.appendAssumeCapacity(.{
            .state = cstate,
            .pos = pos,
        });
    }

    return .{
        .size = size,
        .frame_info = frameInfo,
        .allocator = self.children.allocator,
        .ptr = try State.init(states),
        .ptrEqual = stateEqual,
        .ptrFree = stateFree,
    };
}

fn preFrame(ctx: *anyopaque, frameInfo: Node.FrameInfo, scene: *Scene) anyerror!Node.State {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    var size = vizops.vector.Vector2(usize).zero();
    var states = try std.ArrayList(ChildState).initCapacity(self.children.allocator, self.children.items.len);

    for (self.children.items) |child| {
        const cframeInfo = frameInfo.child(frameInfo.size.avail.sub(size));
        const cstate = try child.node.state(cframeInfo);
        const pos = math.rel(frameInfo, child.pos);

        _ = try child.node.preFrame(cframeInfo, @constCast(&scene.sub(pos, cstate.size)));

        size.value[0] = @max(size.value[0], pos.value[0] + cstate.size.value[0]);
        size.value[1] = @max(size.value[1], pos.value[1] + cstate.size.value[1]);

        states.appendAssumeCapacity(.{
            .state = cstate,
            .pos = pos,
        });
    }

    return .{
        .size = size,
        .frame_info = frameInfo,
        .allocator = self.children.allocator,
        .ptr = try State.init(states),
        .ptrEqual = stateEqual,
        .ptrFree = stateFree,
    };
}

fn frame(ctx: *anyopaque, scene: *Scene) anyerror!void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const frameInfo = self.node.last_state.?.frame_info;

    for (self.children.items) |child| {
        const pos = math.rel(frameInfo, child.pos);
        try child.node.frame(@constCast(&scene.sub(pos, child.node.last_state.?.size)));
    }
}

fn postFrame(ctx: *anyopaque, scene: *Scene) anyerror!void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const frameInfo = self.node.last_state.?.frame_info;

    for (self.children.items) |child| {
        const pos = math.rel(frameInfo, child.pos);
        try child.node.postFrame(@constCast(&scene.sub(pos, child.node.last_state.?.size)));
    }
}

fn deinit(ctx: *anyopaque) void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const alloc = self.children.allocator;

    for (self.children.items) |child| child.node.deinit();
    self.children.deinit();
    alloc.destroy(self);
}
