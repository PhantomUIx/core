const std = @import("std");
const Allocator = std.mem.Allocator;
const SceneNode = @import("../scene.zig").Node;
const BuildContext = @import("BuildContext.zig");
const Widget = @import("Widget.zig");
const Self = @This();

pub const Style = @import("Text/Style.zig");

value: []const u8,
style: ?Style.Data,
widget: Widget,

pub fn create(alloc: Allocator, text: []const u8, style: ?Style.Data) Allocator.Error!*Widget {
    const self = try alloc.create(Self);
    self.* = .{
        .value = text,
        .style = style,
        .widget = .{
            .tag = @typeName(Self),
            .ptr = self,
            .toSceneNodeFn = toSceneNode,
            .formatFn = formatFn,
            .disposeFn = disposeFn,
        },
    };
    return &self.widget;
}

fn toSceneNode(widget: *const Widget, ctx: *BuildContext) anyerror!SceneNode {
    const self: *const Self = @alignCast(@fieldParentPtr("widget", widget));
    const style = self.style orelse blk: {
        const w = ctx.findAncestorWidgetOfType(Style) orelse return error.MissingStyle;
        break :blk w.data;
    };

    return .{
        .text = .{
            .text = self.value,
            .font_size = style.font_size,
            .font = style.font,
        }
    };
}

fn formatFn(widget: *const Widget, options: std.fmt.FormatOptions, writer: std.io.AnyWriter) anyerror!void {
    const self: *const Self = @alignCast(@fieldParentPtr("widget", widget));

    try writer.writeAll(".style = ");
    try std.fmt.formatType(self.style, "?", options, writer, 1);

    try writer.writeAll(", .value = \"");
    try writer.writeAll(self.value);
    try writer.writeAll("\"");
}

fn disposeFn(widget: *Widget, alloc: Allocator) void {
    const self: *Self = @alignCast(@fieldParentPtr("widget", widget));
    alloc.destroy(self);
}

test {
    _ = Style;
}

test "Style on parent compare to style inside" {
    const ctx = try BuildContext.create(std.testing.allocator);
    defer ctx.destroy();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const style_data: Style.Data = .{
        .font = "ABC",
        .font_size = .{ .value = @splat(80) },
    };

    const text: []const u8 = "Hello, world";

    var parent_styled = try Style.create(alloc, style_data, try create(alloc, text, null));
    defer parent_styled.dispose(alloc);

    var inside_styled = try create(alloc, text, style_data);
    defer inside_styled.dispose(alloc);

    try std.testing.expectEqualDeep(try parent_styled.toSceneNode(ctx), inside_styled.toSceneNode(ctx));

    try std.testing.expectEqualDeep(SceneNode{
        .text = .{
            .text = text,
            .font_size = style_data.font_size,
            .font = style_data.font,
        }
    }, try parent_styled.toSceneNode(ctx));

    try std.testing.expectEqualDeep(SceneNode{
        .text = .{
            .text = text,
            .font_size = style_data.font_size,
            .font = style_data.font,
        }
    }, try inside_styled.toSceneNode(ctx));
}
