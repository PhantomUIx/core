const std = @import("std");
const Allocator = std.mem.Allocator;
const Backend = @import("../../base.zig");
const Self = @This();

allocator: Allocator,
base: Backend,

pub fn create(alloc: Allocator) !*Backend {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .base = .{
            .vtable = &.{
                .deinit = deinit,
            },
            .ptr = self,
        },
    };
    return self;
}

fn deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}
