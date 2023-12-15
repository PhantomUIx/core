const std = @import("std");
const Allocator = std.mem.Allocator;
const anyplus = @import("any+");
const vizops = @import("vizops");
const painting = @import("../painting.zig");
const Scene = @import("base.zig");
const Node = @import("node.zig");
const NodeTree = @import("node-tree.zig");
const NodeStack = @This();

tree: NodeTree,
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
        .node = NodeTree.init(T, allocator, id orelse @returnAddress(), @ptrFromInt(@intFromPtr(ptr) + @offsetOf(NodeStack, "tree"))),
    };
}

pub fn create(id: ?usize, args: std.StringHashMap(anyplus.Anytype)) !*Node {
    var self = try new(args.allocator, id orelse @returnAddress());

    if (args.get("children")) |children| {
        try self.children.appendSlice((try children.cast(*const []*Node)).*);
    }
    return &self.tree.node;
}

pub fn new(alloc: Allocator, id: ?usize) Allocator.Error!*NodeStack {
    const self = try alloc.create(NodeStack);
    self.* = .{
        .tree = init(NodeStack, alloc, id orelse @returnAddress(), self),
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
            .pos = vizops.vector.UsizeVector2.zero(),
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
        .tree = init(NodeStack, self.tree.node.allocator, @returnAddress(), d),
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

    for (self.children.items) |child| child.deinit();
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

fn impl_set_properties(ctx: *anyopaque, args: std.StringHashMap(anyplus.Anytype)) anyerror!void {
    const self: *NodeStack = @ptrCast(@alignCast(ctx));

    var iter = args.iterator();
    while (iter.next()) |entry| {
        const key = entry.key_ptr.*;

        if (std.mem.eql(u8, key, "children")) {
            const value = try entry.value_ptr.cast(*const []*Node);
            while (self.children.popOrNull()) |child| child.deinit();

            for (value.*) |child| {
                try self.children.append(try child.dupe());
            }
        } else return error.InvalidKey;
    }
}
