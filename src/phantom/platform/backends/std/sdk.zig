const std = @import("std");
const Allocator = std.mem.Allocator;
const Sdk = @import("../../sdk.zig");
const Package = @import("sdk/step/pkg.zig");
const Self = @This();

base: Sdk,

pub fn create(b: *std.Build) !*Sdk {
    const self = try b.allocator.create(Self);
    errdefer b.allocator.destroy(self);

    self.* = .{
        .base = .{
            .vtable = &.{
                .addPackage = addPackage,
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

fn addPackage(ctx: *anyopaque, _: *std.Build, options: Sdk.Step.Package.Options) *Sdk.Step.Package {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return Package.create(self, options) catch |e| @panic(@errorName(e));
}
