const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const Base = @import("base.zig");
const MemoryFrameBuffer = @This();

base: Base,
info: Base.Info,
buffer: []u8,

pub fn create(alloc: Allocator, info: Base.Info, ptr: [*]u8) !*Base {
    const self = try alloc.create(MemoryFrameBuffer);
    errdefer alloc.destroy(self);

    self.* = .{
        .info = info,
        .buffer = ptr[0..(info.res.value[0] * info.res.value[1] * @divExact(info.colorFormat.width(), 8))],
        .base = .{
            .allocator = alloc,
            .vtable = &.{
                .addr = impl_addr,
                .info = impl_info,
                .dupe = impl_dupe,
                .deinit = impl_deinit,
                .blt = null,
            },
            .ptr = self,
        },
    };
    return &self.base;
}

fn impl_addr(ctx: *anyopaque) anyerror!*anyopaque {
    const self: *MemoryFrameBuffer = @ptrCast(@alignCast(ctx));
    return @ptrCast(@alignCast(self.buffer));
}

fn impl_info(ctx: *anyopaque) Base.Info {
    const self: *MemoryFrameBuffer = @ptrCast(@alignCast(ctx));
    return self.info;
}

fn impl_dupe(ctx: *anyopaque) anyerror!*Base {
    const self: *MemoryFrameBuffer = @ptrCast(@alignCast(ctx));
    const d = try self.base.allocator.create(MemoryFrameBuffer);
    errdefer self.base.allocator.destroy(d);

    d.* = .{
        .info = self.info,
        .buffer = self.buffer,
        .base = .{
            .ptr = d,
            .allocator = self.base.allocator,
            .vtable = self.base.vtable,
        },
    };
    return &d.base;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *MemoryFrameBuffer = @ptrCast(@alignCast(ctx));
    self.base.allocator.destroy(self);
}
