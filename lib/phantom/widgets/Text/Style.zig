const std = @import("std");
const Allocator = std.mem.Allocator;
const math = @import("../../math.zig");
const SceneNode = @import("../../scene.zig").Node;
const BuildContext = @import("../BuildContext.zig");
const Widget = @import("../Widget.zig");
const Self = @This();

pub const Data = struct {
    font_size: math.Vec2(usize),
    font: []const u8,

    pub fn format(self: Data, comptime _: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll(@typeName(Data));

        try writer.writeAll("{ .font_size = ");
        try std.fmt.formatType(self.font_size, "", options, writer, 2);

        try writer.writeAll(", .font = \"");
        try writer.writeAll(self.font);
        try writer.writeAll("\" }");
    }
};

data: Data,
child: *Widget,
widget: Widget,

pub fn create(alloc: Allocator, data: Data, child: *Widget) Allocator.Error!*Widget {
    const self = try alloc.create(Self);
    self.* = .{
        .data = data,
        .child = child,
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
    return self.child.toSceneNode(ctx);
}

fn formatFn(widget: *const Widget, options: std.fmt.FormatOptions, writer: std.io.AnyWriter) anyerror!void {
    const self: *const Self = @alignCast(@fieldParentPtr("widget", widget));

    try writer.writeAll(".data = ");
    try std.fmt.formatType(self.data, "", options, writer, 1);

    try writer.writeAll(", .child = ");
    try std.fmt.formatType(self.child, "", options, writer, 1);
}

fn disposeFn(widget: *Widget, alloc: Allocator) void {
    const self: *Self = @alignCast(@fieldParentPtr("widget", widget));
    self.child.dispose(alloc);
    alloc.destroy(self);
}
