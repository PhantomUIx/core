const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const math = @import("../math.zig");
const Scene = @import("base.zig");
const Node = @import("node.zig");
const NodeTree = @This();

pub const Child = struct {
    node: *Node,
    pos: vizops.vector.UsizeVector2,
};

pub const VTable = struct {
    children: *const fn (*anyopaque, Node.FrameInfo) anyerror!std.ArrayList(Child),
    overflow: ?*const fn (*anyopaque, node: *Node) anyerror!void,
    dupe: *const fn (*anyopaque) anyerror!*Node,
    deinit: ?*const fn (*anyopaque) void = null,
    format: ?*const fn (*anyopaque, ?Allocator) anyerror!std.ArrayList(u8) = null,
    setProperties: ?*const fn (*anyopaque, std.StringHashMap(?*anyopaque)) anyerror!void = null,
};

const ChildState = struct {
    state: Node.State,
    pos: vizops.vector.UsizeVector2,

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
        self.children.deinit();
        self.children.allocator.destroy(self);
    }
};

node: Node,
vtable: *const VTable,
ptr: *anyopaque,

pub inline fn init(comptime T: type, id: ?usize, ptr: *anyopaque) Node {
    return .{
        .ptr = ptr,
        .type = @typeName(T),
        .id = id orelse @returnAddress(),
        .vtable = &.{
            .dupe = dupe,
            .state = state,
            .preFrame = preFrame,
            .frame = frame,
            .postFrame = postFrame,
            .deinit = deinit,
            .format = format,
            .setProperties = setProperties,
        },
    };
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

fn dupe(ctx: *anyopaque) anyerror!*Node {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    return self.vtable.dupe(self.ptr);
}

fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!Node.State {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    var size = vizops.vector.UsizeVector2.zero();

    const children = try self.vtable.children(self.ptr, frameInfo);
    defer children.deinit();

    var states = std.ArrayList(ChildState).init(children.allocator);
    errdefer states.deinit();

    for (children.items) |child| {
        const childSize = frameInfo.size.avail.sub(size);
        if (std.simd.countTrues(childSize.value == vizops.vector.UsizeVector2.zero().value) == 2 and self.vtable.overflow != null) {
            const overflow = self.vtable.overflow.?;
            try overflow(self.ptr, child.node);
        }

        const cstate = try child.node.state(frameInfo.child(childSize));
        errdefer cstate.deinit(children.allocator);

        size.value[0] = @max(size.value[0], child.pos.value[0] + cstate.size.value[0]);
        size.value[1] = @max(size.value[1], child.pos.value[1] + cstate.size.value[1]);

        try states.append(.{
            .state = cstate,
            .pos = child.pos,
        });
    }

    return .{
        .size = size,
        .frame_info = frameInfo,
        .allocator = children.allocator,
        .ptr = try State.init(states),
        .ptrEqual = stateEqual,
        .ptrFree = stateFree,
    };
}

fn preFrame(ctx: *anyopaque, frameInfo: Node.FrameInfo, scene: *Scene) anyerror!Node.State {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    var size = vizops.vector.UsizeVector2.zero();

    const children = try self.vtable.children(self.ptr, frameInfo);
    defer children.deinit();

    var states = std.ArrayList(ChildState).init(children.allocator);
    errdefer states.deinit();

    for (children.items) |child| {
        const childSize = frameInfo.size.avail.sub(size);
        if (std.simd.countTrues(childSize.value == vizops.vector.UsizeVector2.zero().value) == 2 and self.vtable.overflow != null) {
            const overflow = self.vtable.overflow.?;
            try overflow(self.ptr, child.node);
        }

        const cframeInfo = frameInfo.child(childSize);
        const cstate = try child.node.state(cframeInfo);
        errdefer cstate.deinit(children.allocator);

        _ = try child.node.preFrame(cframeInfo, @constCast(&scene.sub(child.pos, cstate.size)));

        size.value[0] = @max(size.value[0], child.pos.value[0] + cstate.size.value[0]);
        size.value[1] = @max(size.value[1], child.pos.value[1] + cstate.size.value[1]);

        try states.append(.{
            .state = cstate,
            .pos = child.pos,
        });
    }

    return .{
        .size = size,
        .frame_info = frameInfo,
        .allocator = children.allocator,
        .ptr = try State.init(states),
        .ptrEqual = stateEqual,
        .ptrFree = stateFree,
    };
}

fn frame(ctx: *anyopaque, scene: *Scene) anyerror!void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const frameInfo = self.node.last_state.?.frame_info;

    const children = try self.vtable.children(self.ptr, frameInfo);
    defer children.deinit();

    for (children.items) |child| {
        try child.node.frame(@constCast(&scene.sub(child.pos, child.node.last_state.?.size)));
    }
}

fn postFrame(ctx: *anyopaque, scene: *Scene) anyerror!void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    const frameInfo = self.node.last_state.?.frame_info;

    const children = try self.vtable.children(self.ptr, frameInfo);
    defer children.deinit();

    for (children.items) |child| {
        try child.node.postFrame(@constCast(&scene.sub(child.pos, child.node.last_state.?.size)));
    }
}

fn deinit(ctx: *anyopaque) void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    if (self.vtable.deinit) |f| f(self.ptr);
}

fn format(ctx: *anyopaque, optAlloc: ?Allocator) anyerror!std.ArrayList(u8) {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    if (self.vtable.format) |f| return f(self.ptr, optAlloc);

    if (optAlloc) |alloc| {
        var output = std.ArrayList(u8).init(alloc);
        errdefer output.deinit();

        try output.writer().writeAll("{");

        if (self.node.last_state) |lastState| {
            if (self.vtable.children(self.ptr, lastState.frame_info) catch null) |children| {
                try output.writer().print(" .children = [{}] {any}", .{ children.items.len, children.items });
            }
        }

        try output.writer().writeAll(" }");
        return output;
    }
    return error.NoAlloc;
}

fn setProperties(ctx: *anyopaque, args: std.StringHashMap(?*anyopaque)) anyerror!void {
    const self: *NodeTree = @ptrCast(@alignCast(ctx));
    return if (self.vtable.setProperties) |f| f(self.ptr, args) else error.NoProperties;
}
