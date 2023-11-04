const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const painting = @import("../painting.zig");
const Scene = @import("base.zig");
const Node = @import("node.zig");
const NodeTree = @import("node-tree.zig");
const NodeStack = @This();

tree: NodeTree,
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
        .node = NodeTree.init(T, id orelse @returnAddress(), @ptrFromInt(@intFromPtr(ptr) + @offsetOf(NodeStack, "tree"))),
    };
}

pub fn create(id: ?usize, args: std.StringHashMap(?*anyopaque)) !*Node {
    var self = try new(args.allocator, id orelse @returnAddress());

    if (args.get("children")) |childrenPtr| {
        const childrenLen = @intFromPtr(args.get("children.len") orelse return error.MissingKey);
        const children = @as([*]const *Node, @ptrCast(@alignCast(childrenPtr)))[0..childrenLen];
        try self.children.appendSlice(children);
    }
    return &self.tree.node;
}

pub fn new(alloc: Allocator, id: ?usize) Allocator.Error!*NodeStack {
    const self = try alloc.create(NodeStack);
    self.* = .{
        .tree = init(NodeStack, id orelse @returnAddress(), self),
        .children = std.ArrayList(*Node).init(alloc),
    };
    return self;
}

fn impl_children(ctx: *anyopaque, _: Node.FrameInfo) anyerror!std.ArrayList(NodeTree.Child) {
    const self: *NodeStack = @ptrCast(@alignCast(ctx));
    var v = try std.ArrayList(NodeTree.Child).initCapacity(self.children.allocator, self.children.items.len);
    errdefer v.deinit();

    for (self.children.items) |child| {
        v.appendAssumeCapacity(.{
            .node = child,
            .pos = vizops.vector.Vector2(usize).zero(),
        });
    }

    return v;
}

fn impl_overflow(ctx: *anyopaque, node: *Node) anyerror!void {
    const self: *NodeStack = @ptrCast(@alignCast(ctx));
    var name = std.ArrayList(u8).init(self.children.allocator);
    defer name.deinit();

    try node.formatName(self.children.allocator, name.writer());

    std.debug.panic("Node {s} is overflowing", .{name.items});
}

fn impl_dupe(ctx: *anyopaque) anyerror!*Node {
    const self: *NodeStack = @ptrCast(@alignCast(ctx));
    const d = try self.children.allocator.create(NodeStack);
    errdefer self.children.allocator.destroy(d);

    d.* = .{
        .tree = init(NodeStack, @returnAddress(), d),
        .children = try std.ArrayList(*Node).initCapacity(self.children.allocator, self.children.items.len),
    };

    errdefer d.children.deinit();

    for (self.children.items) |child| {
        d.children.appendAssumeCapacity(try child.dupe());
    }
    return &d.tree.node;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *NodeStack = @ptrCast(@alignCast(ctx));
    const alloc = self.children.allocator;
    self.children.deinit();
    alloc.destroy(self);
}

fn impl_format(ctx: *anyopaque, _: ?Allocator) anyerror!std.ArrayList(u8) {
    const self: *NodeStack = @ptrCast(@alignCast(ctx));

    var output = std.ArrayList(u8).init(self.children.allocator);
    errdefer output.deinit();

    try output.writer().print("{{ .children = [{}] {any} }}", .{ self.children.items.len, self.children.items });
    return output;
}
