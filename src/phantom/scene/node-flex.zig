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

pub inline fn init(comptime T: type, allocator: Allocator, id: ?usize, ptr: *anyopaque) NodeTree {
    return .{
        .vtable = &.{
            .children = impl_children,
            .overflow = impl_overflow,
            .dupe = impl_dupe,
            .deinit = impl_deinit,
            .format = impl_format,
            .setProperties = impl_set_properties,
        },
        .ptr = ptr,
        .node = NodeTree.init(T, allocator, id orelse @returnAddress(), @ptrFromInt(@intFromPtr(ptr) + @offsetOf(NodeFlex, "tree"))),
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
        .tree = init(NodeFlex, alloc, id orelse @returnAddress(), self),
        .direction = direction,
        .children = std.ArrayList(*Node).init(alloc),
    };
    return self;
}

fn impl_children(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!std.ArrayList(NodeTree.Child) {
    const self: *NodeFlex = @ptrCast(@alignCast(ctx));
    var v = try std.ArrayList(NodeTree.Child).initCapacity(self.children.allocator, self.children.items.len);
    errdefer v.deinit();

    var pos = vizops.vector.UsizeVector2.zero();

    for (self.children.items) |child| {
        const cstate = try child.state(frameInfo);
        defer cstate.deinit(self.children.allocator);

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
        .tree = init(NodeFlex, self.children.allocator, @returnAddress(), d),
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

    for (self.children.items) |child| child.deinit();
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

fn impl_set_properties(ctx: *anyopaque, args: std.StringHashMap(?*anyopaque)) anyerror!void {
    const self: *NodeFlex = @ptrCast(@alignCast(ctx));

    var iter = args.iterator();
    while (iter.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;
        if (value == null) continue;

        if (std.mem.eql(u8, key, "children")) {
            while (self.children.popOrNull()) |child| child.deinit();

            const childrenLen = @intFromPtr(args.get("children.len") orelse return error.MissingKey);
            const children = @as([*]const *Node, @ptrCast(@alignCast(value.?)))[0..childrenLen];
            for (children) |child| {
                try self.children.append(try child.dupe());
            }
        } else if (std.mem.eql(u8, key, "direction")) {
            self.direction = @enumFromInt(@intFromPtr(value.?));
        } else if (std.mem.eql(u8, key, "children.len")) {} else return error.InvalidKey;
    }
}
