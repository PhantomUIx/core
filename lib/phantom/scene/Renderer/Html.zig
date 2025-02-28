const std = @import("std");
const Allocator = std.mem.Allocator;
const graphics = @import("../../graphics.zig");
const math = @import("../../math.zig");
const SceneNode = @import("../../scene.zig").Node;
const Renderer = @import("../Renderer.zig");

fn fmtColor(color: graphics.Color, writer: anytype) !void {
    try writer.writeAll("rgba(");
    try std.fmt.formatInt(@as(usize, @intFromFloat(color.value[0] * 255)), 10, .lower, .{}, writer);

    try writer.writeAll(", ");
    try std.fmt.formatInt(@as(usize, @intFromFloat(color.value[1] * 255)), 10, .lower, .{}, writer);

    try writer.writeAll(", ");
    try std.fmt.formatInt(@as(usize, @intFromFloat(color.value[2] * 255)), 10, .lower, .{}, writer);

    try writer.writeAll(", ");
    try std.fmt.formatType(color.value[3], "d", .{}, writer, 0);

    try writer.writeAll(")");
}

pub fn Writer(comptime WriterType: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        base: Renderer,
        writer: WriterType,

        const vtable: Renderer.VTable = .{
            .render = vtable_render,
            .destroy = vtable_destroy,
        };

        pub fn create(alloc: Allocator, writer: WriterType) Allocator.Error!*Renderer {
            const self = try alloc.create(Self);
            errdefer alloc.destroy(self);

            self.* = .{
                .allocator = alloc,
                .base = .{
                    .ptr = self,
                    .vtable = &vtable,
                },
                .writer = writer,
            };
            return &self.base;
        }

        pub fn render(self: *Self, node: SceneNode) anyerror!void {
            switch (node) {
                .container => |container| {
                    try self.writer.writeAll("<div");

                    var props = std.ArrayList(u8).init(self.allocator);
                    defer props.deinit();

                    if (container.style.background_color) |bg| {
                        if (props.items.len > 0) try props.appendSlice("; ");

                        try props.appendSlice("background-color: ");
                        try fmtColor(bg, props.writer());
                    }

                    if (container.style.border_radius) |br| {
                        if (br.top_left) |value| {
                            if (props.items.len > 0) try props.appendSlice("; ");

                            try props.appendSlice("border-top-left-radius: ");
                            try std.fmt.formatInt(@as(usize, @intFromFloat(value)), 10, .lower, .{}, props.writer());
                        }

                        if (br.top_right) |value| {
                            if (props.items.len > 0) try props.appendSlice("; ");

                            try props.appendSlice("border-top-right-radius: ");
                            try std.fmt.formatInt(@as(usize, @intFromFloat(value)), 10, .lower, .{}, props.writer());
                        }

                        if (br.bottom_left) |value| {
                            if (props.items.len > 0) try props.appendSlice("; ");

                            try props.appendSlice("border-bottom-left-radius: ");
                            try std.fmt.formatInt(@as(usize, @intFromFloat(value)), 10, .lower, .{}, props.writer());
                        }

                        if (br.bottom_right) |value| {
                            if (props.items.len > 0) try props.appendSlice("; ");

                            try props.appendSlice("border-bottom-right-radius: ");
                            try std.fmt.formatInt(@as(usize, @intFromFloat(value)), 10, .lower, .{}, props.writer());
                        }
                    }

                    if (container.layout.size) |size| {
                        if (props.items.len > 0) try props.appendSlice("; ");

                        try props.appendSlice("width: ");
                        try std.fmt.formatInt(@as(usize, @intFromFloat(size.value[0])), 10, .lower, .{}, props.writer());

                        try props.appendSlice("px; height: ");
                        try std.fmt.formatInt(@as(usize, @intFromFloat(size.value[1])), 10, .lower, .{}, props.writer());

                        try props.appendSlice("px");
                    }

                    if (props.items.len > 0) {
                        try self.writer.writeAll(" style=\"");
                        try self.writer.writeAll(props.items);
                        try self.writer.writeByte('"');
                    }

                    try self.writer.writeByte('>');

                    for (container.children) |child| {
                        try self.render(child);
                    }

                    try self.writer.writeAll("</div>");
                },
                else => {},
            }
        }

        pub fn destroy(self: *Self) void {
            self.allocator.destroy(self);
        }

        fn vtable_render(ptr: *anyopaque, node: SceneNode) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            return self.render(node);
        }

        fn vtable_destroy(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            return self.destroy();
        }
    };
}

test {
    const ArrayList = std.ArrayList(u8);
    const HtmlWriterRenderer = Writer(ArrayList.Writer);

    var buffer = ArrayList.init(std.testing.allocator);
    defer buffer.deinit();

    const renderer = try HtmlWriterRenderer.create(std.testing.allocator, buffer.writer());
    defer renderer.destroy();

    try renderer.render(.{
        .container = .{
            .style = .{
                .background_color = graphics.Color.init(.{ 0.14, 0.15, 0.23, 1.0 }),
            },
            .layout = .{
                .size = .{ .value = .{ 100, 100 } },
            },
            .children = &.{},
        },
    });

    try std.testing.expectEqualStrings("<div style=\"background-color: rgba(35, 38, 58, 1); width: 100px; height: 100px\"></div>", buffer.items);
}
