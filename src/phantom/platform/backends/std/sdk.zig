const std = @import("std");
const Allocator = std.mem.Allocator;
const Sdk = @import("../../sdk.zig");
const Self = @This();

base: Sdk,

pub fn create(b: *std.Build) !*Sdk {
    const self = try b.allocator.create(Self);
    errdefer b.allocator.destroy(self);

    self.* = .{
        .base = .{
            .vtable = &.{
                .deinit = deinit,
            },
            .ptr = self,
            .owner = b,
        },
    };
    return &self.base;
}

fn deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.base.owner.allocator.destroy(self);
}
