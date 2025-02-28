const std = @import("std");
const Allocator = std.mem.Allocator;
const SceneNode = @import("../scene.zig").Node;
const BuildContext = @import("BuildContext.zig");
const Self = @This();

tag: []const u8,
ptr: ?*anyopaque = null,
needsRebuildFn: ?*const fn (*const Self, *const BuildContext) bool = null,
disposeFn: ?*const fn (*Self, Allocator) void = null,
toSceneNodeFn: *const fn (*const Self, *BuildContext) anyerror!SceneNode,
formatFn: ?*const fn (*const Self, options: std.fmt.FormatOptions, writer: std.io.AnyWriter) anyerror!void = null,

pub fn needsRebuild(self: *const Self, ctx: *const BuildContext) bool {
    if (self.needsRebuildFn) |f| {
        const self_ctx = try ctx.inner(self);
        return f(self, self_ctx);
    }
    return false;
}

pub inline fn dispose(self: *Self, alloc: Allocator) void {
    if (self.disposeFn) |f| return f(self, alloc);
}

pub inline fn toSceneNode(self: *const Self, ctx: *BuildContext) anyerror!SceneNode {
    const self_ctx = try ctx.inner(self);
    return try self.toSceneNodeFn(self, self_ctx);
}

pub inline fn format(self: *const Self, comptime _: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.writeAll(self.tag);
    try writer.writeAll("{ ");
    if (self.formatFn) |f| {
        try f(self, options, if (@hasDecl(@TypeOf(writer), "any")) writer.any() else writer);
        try writer.writeByte(' ');
    }
    try writer.writeByte('}');
}
