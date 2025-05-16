const std = @import("std");
const Allocator = std.mem.Allocator;
const math = @import("../math.zig");
const FontManager = @import("../fonts/Manager.zig");
const SceneNode = @import("../scene.zig").Node;
const SceneRenderer = @import("../scene/Renderer.zig");
const BuildContext = @import("BuildContext.zig");
const Widget = @import("Widget.zig");
const Self = @This();

allocator: Allocator,
build_context: *BuildContext,
renderer: *SceneRenderer,
font_manager: *FontManager,
child: ?*const Widget,
widget: Widget,

pub fn create(alloc: Allocator, renderer: *SceneRenderer) !*Self {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    const build_context = try BuildContext.create(alloc);
    errdefer build_context.destroy();

    const font_manager = try FontManager.create(alloc);
    errdefer font_manager.destroy();

    self.* = .{
        .allocator = alloc,
        .build_context = build_context,
        .renderer = renderer,
        .font_manager = font_manager,
        .child = null,
        .widget = .{
            .tag = @typeName(Self),
            .ptr = self,
            .toSceneNodeFn = impl_toSceneNodeFn,
            .disposeFn = impl_disposeFn,
        },
    };
    return self;
}

pub fn destroy(self: *Self) void {
    self.font_manager.destroy();
    self.build_context.destroy();
    self.allocator.destroy(self);
}

pub fn render(self: *Self) anyerror!void {
    // TODO: cache the root node and rebuild the tree as needed.
    const root_node = try self.widget.toSceneNode(self.build_context);
    try self.renderer.render(root_node);
}

fn impl_toSceneNodeFn(widget: *Widget, ctx: *BuildContext) anyerror!SceneNode {
    const self: *Self = @fieldParentPtr("widget", widget);
    const child = self.child orelse return error.NoChild;
    return try child.toSceneNode(ctx);
}

fn impl_disposeFn(widget: *Widget) void {
    const self: *Self = @fieldParentPtr("widget", widget);
    self.destroy();
}
