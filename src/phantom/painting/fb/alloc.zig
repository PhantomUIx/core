const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const Base = @import("base.zig");
const AllocatedFrameBuffer = @This();

base: Base,
info: Base.Info,
buffer: []u8,

pub fn create(alloc: Allocator, info: Base.Info) !*Base {
    const fourcc = try vizops.color.fourcc.Value.decode(info.format);

    const self = try alloc.create(AllocatedFrameBuffer);
    errdefer alloc.destroy(self);

    self.* = .{
        .info = info,
        .buffer = try alloc.alloc(u8, info.res.value[0] * info.res.value[1] * @divExact(fourcc.width(), 8)),
        .base = .{
            .allocator = alloc,
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
    const d = try self.base.allocator.create(AllocatedFrameBuffer);
    errdefer self.base.allocator.destroy(d);

    d.* = .{
        .allocator = self.base.allocator,
        .info = self.info,
        .buffer = try self.base.allocator.dupe(u8, self.buffer),
        .base = .{
            .ptr = d,
            .vtable = self.base.vtable,
        },
    };
    return d;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *AllocatedFrameBuffer = @ptrCast(@alignCast(ctx));
    self.base.allocator.free(self.buffer);
    self.base.allocator.destroy(self);
}
