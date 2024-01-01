const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const Base = @import("base.zig");
const FileDescriptorFrameBuffer = @This();

base: Base,
info: Base.Info,
fd: std.os.fd_t,
buffer: []align(std.mem.page_size) u8,

pub fn create(alloc: Allocator, info: Base.Info, fd: std.os.fd_t) !*Base {
    const self = try alloc.create(FileDescriptorFrameBuffer);
    errdefer alloc.destroy(self);

    self.* = .{
        .info = info,
        .fd = fd,
        .buffer = try std.os.mmap(null, info.res.value[0] * info.res.value[1] * @divExact(info.colorFormat.width(), 8), std.os.PROT.READ | std.os.PROT.WRITE, std.os.MAP.SHARED, fd, 0),
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
    errdefer std.os.munmap(self.fd, self.buffer);
    return &self.base;
}

fn impl_addr(ctx: *anyopaque) anyerror!*anyopaque {
    const self: *FileDescriptorFrameBuffer = @ptrCast(@alignCast(ctx));
    return @ptrCast(@alignCast(self.buffer));
}

fn impl_info(ctx: *anyopaque) Base.Info {
    const self: *FileDescriptorFrameBuffer = @ptrCast(@alignCast(ctx));
    return self.info;
}

fn impl_dupe(ctx: *anyopaque) anyerror!*Base {
    const self: *FileDescriptorFrameBuffer = @ptrCast(@alignCast(ctx));
    const d = try self.base.allocator.create(FileDescriptorFrameBuffer);
    errdefer self.base.allocator.destroy(d);

    d.* = .{
        .info = self.info,
        .fd = self.fd,
        .buffer = try std.os.mmap(null, self.info.res.value[0] * self.info.res.value[1] * @divExact(self.info.colorFormat.width(), 8), std.os.PROT.READ | std.os.PROT.WRITE, std.os.MAP.SHARED, self.fd, 0),
        .base = .{
            .ptr = d,
            .allocator = self.base.allocator,
            .vtable = self.base.vtable,
        },
    };
    return &d.base;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *FileDescriptorFrameBuffer = @ptrCast(@alignCast(ctx));
    std.os.munmap(self.fd, self.buffer);
    self.base.allocator.destroy(self);
}
