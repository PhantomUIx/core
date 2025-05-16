const std = @import("std");
const Allocator = std.mem.Allocator;
const libdrm = @import("libdrm");
const Connector = @import("../../Connector.zig");
const Device = @import("../../Device.zig");
const Self = @This();

allocator: Allocator,
node: libdrm.Node,
base: Device,

pub fn create(alloc: Allocator, node: libdrm.Node) !*Device {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .node = node,
        .base = .{
            .ptr = self,
            .vtable = &.{
                .getConnectors = impl_getConnectors,
                .destroy = impl_destroy,
            },
        },
    };
    return &self.base;
}

pub fn getConnectors(self: *Self) ![]const *Connector {
    var list = std.ArrayList(*Connector).init(self.allocator);
    defer list.deinit();

    const modeCardRes = try self.node.getModeCardRes();
    defer modeCardRes.deinit(self.allocator);

    if (modeCardRes.connectorIds()) |connectorIds| {
        for (connectorIds) |connectorId| {
            std.debug.print("{}\n", .{connectorId});
        }
    }
    return try list.toOwnedSlice();
}

pub fn destroy(self: *Self) void {
    self.node.deinit();
    self.allocator.destroy(self);
}

fn impl_getConnectors(ptr: *anyopaque) anyerror![]const *Connector {
    const self: *Self = @alignCast(@ptrCast(ptr));
    return self.getConnectors();
}

fn impl_destroy(ptr: *anyopaque) void {
    const self: *Self = @alignCast(@ptrCast(ptr));
    return self.destroy();
}
