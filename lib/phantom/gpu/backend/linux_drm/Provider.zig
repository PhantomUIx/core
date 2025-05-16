const std = @import("std");
const Allocator = std.mem.Allocator;
const libdrm = @import("libdrm");
const Provider = @import("../../Provider.zig");
const Device = @import("../../Device.zig");
const LinuxDrmDevice = @import("Device.zig");
const Self = @This();

allocator: Allocator,
base: Provider,

pub fn create(alloc: Allocator) !*Provider {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .base = .{
            .ptr = self,
            .vtable = &.{
                .getDevices = impl_getDevices,
                .destroy = impl_destroy,
            },
        },
    };
    return &self.base;
}

pub fn getDevices(self: *Self) anyerror![]const *Device {
    var list = std.ArrayList(*Device).init(self.allocator);
    defer list.deinit();

    var iter = libdrm.Node.Iterator.init(self.allocator, .primary);
    while (iter.next()) |node| {
        const device = try LinuxDrmDevice.create(self.allocator, node);
        errdefer device.destroy();

        try list.append(device);
    }

    return try list.toOwnedSlice();
}

pub fn destroy(self: *Self) void {
    self.allocator.destroy(self);
}

fn impl_getDevices(ptr: *anyopaque) anyerror![]const *Device {
    const self: *Self = @alignCast(@ptrCast(ptr));
    return self.getDevices();
}

fn impl_destroy(ptr: *anyopaque) void {
    const self: *Self = @alignCast(@ptrCast(ptr));
    return self.destroy();
}

test {
    const provider = try create(std.testing.allocator);
    defer provider.destroy();

    const devices = try provider.getDevices();
    defer {
        for (devices) |dev| dev.destroy();
        std.testing.allocator.free(devices);
    }

    if (devices.len == 0) return error.SkipZigTest;

    std.debug.print("{any}\n", .{devices});

    for (devices) |dev| {
        const connectors = dev.getConnectors() catch continue;
        defer {
            for (connectors) |conn| conn.destroy();
            std.testing.allocator.free(connectors);
        }

        std.debug.print("{any}\n", .{connectors});
    }
}
