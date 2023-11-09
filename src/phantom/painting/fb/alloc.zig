const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const Base = @import("base.zig");
const AllocatedFrameBuffer = @This();

allocator: Allocator,
base: Base,
info: Base.Info,
buffer: []u8,

pub fn create(alloc: Allocator, info: Base.Info) !*Base {
    const fourcc = try vizops.fourcc.Value.decode(info.format);

    const self = try alloc.create(AllocatedFrameBuffer);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .info = info,
        .buffer = try alloc.alloc(u8, info.res.value[0] * info.res.value[1] * @divExact(fourcc.width(), 8)),
        .base = .{
            .vtable = &.{
                .addr = impl_addr,
                .info = impl_info,
                .dupe = impl_dupe,
                .deinit = impl_deinit,
            },
            .ptr = self,
        },
    };
    errdefer alloc.free(self.buffer);
    return &self.base;
}

fn impl_addr(ctx: *anyopaque) anyerror!*anyopaque {
    const self: *AllocatedFrameBuffer = @ptrCast(@alignCast(ctx));
    return self.buffer;
}

fn impl_info(ctx: *anyopaque) Base.Info {
    const self: *AllocatedFrameBuffer = @ptrCast(@alignCast(ctx));
    return self.info;
}

fn impl_dupe(ctx: *anyopaque) anyerror!*Base {
    const self: *AllocatedFrameBuffer = @ptrCast(@alignCast(ctx));
    const d = try self.allocator.create(AllocatedFrameBuffer);
    errdefer self.allocator.destroy(d);

    d.* = .{
        .allocator = self.allocator,
        .info = self.info,
        .buffer = try self.allocator.dupe(u8, self.buffer),
        .base = .{
            .ptr = d,
            .vtable = self.base.vtable,
        },
    };
    return d;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *AllocatedFrameBuffer = @ptrCast(@alignCast(ctx));
    self.allocator.free(self.buffer);
    self.allocator.destroy(self);
}
