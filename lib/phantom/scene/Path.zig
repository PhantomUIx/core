const std = @import("std");
const SceneNode = @import("../scene.zig").Node;
const Self = @This();

pub const Error = error {
    InvalidType,
    InvalidIndex,
};

pub const Item = union(enum) {
    index: usize,
    tag: []const u8,

    pub fn access(self: Item, node: *const SceneNode) Error!*const SceneNode {
        return switch (self) {
            .index => |i| blk: {
                if (node.* == .container) {
                    if (i >= node.container.children.len) break :blk Error.InvalidIndex;
                    break :blk &node.container.children[i];
                }
                break :blk Error.InvalidType;
            },
            .tag => |t| if (std.mem.eql(u8, t, @tagName(node.*))) node else Error.InvalidType,
        };
    }
};

pub const Iterator = struct {
    path: []const Item,
    index: usize = 0,

    pub fn peek(self: *Iterator) ?Item {
        if (self.index >= self.path.len) return null;
        return self.path[self.index];
    }

    pub fn next(self: *Iterator) ?Item {
        const item = self.peek() orelse return null;
        self.index += 1;
        return item;
    }
};

pub fn access(path: []const Item, node: *const SceneNode) (Error || error{UnexpectedTag})!*const SceneNode {
    var iter: Iterator = .{ .path = path };

    var curr_node = node;
    while (iter.next()) |tagItem| {
        const indexItem = if (iter.peek()) |item| blk: {
            iter.index += 1;
            break :blk item;
        } else null;

        if (tagItem != .tag and indexItem != null) return error.UnexpectedTag;
        curr_node = try (indexItem orelse tagItem).access(curr_node);
    }
    return curr_node;
}

test {
    const node: SceneNode = .{ .container = .{
        .layout = .{},
        .style = .{},
        .children = &.{
            .{ .container = .{
                .layout = .{},
                .style = .{},
                .children = &.{
                    .{ .text = .{
                        .text = "Hello, world",
                        .font = "ABC",
                        .font_size = .{ .value = @splat(30) },
                    } },
                    .{ .text = .{
                        .text = "The quick brown fox jumps over the lazy dog",
                        .font = "ABC",
                        .font_size = .{ .value = @splat(30) },
                    } },
                },
            } },
        },
    } };

    try std.testing.expectEqualDeep(&node.container.children[0].container.children[0], try access(&.{
        .{ .tag = "container" },
        .{ .index = 0 },
        .{ .tag = "container" },
        .{ .index = 0 },
        .{ .tag = "text" },
    }, &node));

    try std.testing.expectEqualDeep(&node.container.children[0].container.children[1], try access(&.{
        .{ .tag = "container" },
        .{ .index = 0 },
        .{ .tag = "container" },
        .{ .index = 1 },
        .{ .tag = "text" },
    }, &node));
}
