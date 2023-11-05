const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const painting = @import("../painting.zig");
const Scene = @import("base.zig");
const Node = @import("node.zig");
const NodeTree = @import("node-tree.zig");
const NodeFlex = @This();

tree: NodeTree,
direction: painting.Axis,
children: std.ArrayList(*Node),

pub inline fn init(comptime T: type, id: ?usize, ptr: *anyopaque) NodeTree {
    return .{
        .vtable = &.{
            .children = impl_children,
            .overflow = impl_overflow,
            .dupe = impl_dupe,
            .deinit = impl_deinit,
            .format = impl_format,
        },
        .ptr = ptr,
        .node = NodeTree.init(T, id orelse @returnAddress(), @ptrFromInt(@intFromPtr(ptr) + @offsetOf(NodeFlex, "tree"))),
    };
}

pub fn create(id: ?usize, args: std.StringHashMap(?*anyopaque)) !*Node {
    const direction: painting.Axis = @enumFromInt(@intFromPtr(args.get("direction") orelse return error.MissingKey));
    var self = try new(args.allocator, id orelse @returnAddress(), direction);

    if (args.get("children")) |childrenPtr| {
        const childrenLen = @intFromPtr(args.get("children.len") orelse return error.MissingKey);
        const children = @as([*]const *Node, @ptrCast(@alignCast(childrenPtr)))[0..childrenLen];
        try self.children.appendSlice(children);
    }
    return &self.tree.node;
}

pub fn new(alloc: Allocator, id: ?usize, direction: painting.Axis) Allocator.Error!*NodeFlex {
    const self = try alloc.create(NodeFlex);
    self.* = .{
        .tree = init(NodeFlex, id orelse @returnAddress(), self),
        .direction = direction,
        .children = std.ArrayList(*Node).init(alloc),
    };
    return self;
}

fn impl_children(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!std.ArrayList(NodeTree.Child) {
    const self: *NodeFlex = @ptrCast(@alignCast(ctx));
    var v = try std.ArrayList(NodeTree.Child).initCapacity(self.children.allocator, self.children.items.len);
    errdefer v.deinit();

    var pos = vizops.vector.Vector2(usize).zero();

    for (self.children.items) |child| {
        const cstate = try child.state(frameInfo);

        v.appendAssumeCapacity(.{
            .node = child,
            .pos = pos,
        });

        pos = pos.add(vizops.vector.UsizeVector2.init([_]usize{
            if (self.direction == .horizontal) cstate.size.value[0] else 0,
            if (self.direction == .vertical) cstate.size.value[1] else 0,
        }));
    }

    return v;
}

fn impl_overflow(ctx: *anyopaque, node: *Node) anyerror!void {
    const self: *NodeFlex = @ptrCast(@alignCast(ctx));
    var name = std.ArrayList(u8).init(self.children.allocator);
    defer name.deinit();

    try node.formatName(self.children.allocator, name.writer());

    std.debug.panic("Node {s} is overflowing", .{name.items});
}

fn impl_dupe(ctx: *anyopaque) anyerror!*Node {
    const self: *NodeFlex = @ptrCast(@alignCast(ctx));
    const d = try self.children.allocator.create(NodeFlex);
    errdefer self.children.allocator.destroy(d);

    d.* = .{
        .tree = init(NodeFlex, @returnAddress(), d),
        .direction = self.direction,
        .children = try std.ArrayList(*Node).initCapacity(self.children.allocator, self.children.items.len),
    };

    errdefer d.children.deinit();

    for (self.children.items) |child| {
        d.children.appendAssumeCapacity(try child.dupe());
    }
    return &d.tree.node;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *NodeFlex = @ptrCast(@alignCast(ctx));
    const alloc = self.children.allocator;
    self.children.deinit();
    alloc.destroy(self);
}

fn impl_format(ctx: *anyopaque, _: ?Allocator) anyerror!std.ArrayList(u8) {
    const self: *NodeFlex = @ptrCast(@alignCast(ctx));

    var output = std.ArrayList(u8).init(self.children.allocator);
    errdefer output.deinit();

    try output.writer().print("{{ .direction = {?s}, .children = [{}] {any} }}", .{ std.enums.tagName(painting.Axis, self.direction), self.children.items.len, self.children.items });
    return output;
}
