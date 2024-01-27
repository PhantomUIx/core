const std = @import("std");
const Allocator = std.mem.Allocator;
const Sdk = @import("../../sdk.zig");
const Package = @import("sdk/step/pkg.zig");
const InstallPackage = @import("sdk/step/install-pkg.zig");
const Self = @This();

base: Sdk,

pub fn create(b: *std.Build, phantom: *std.Build.Module) !*Sdk {
    const self = try b.allocator.create(Self);
    errdefer b.allocator.destroy(self);

    self.* = .{
        .base = .{
            .vtable = &.{
                .addPackage = addPackage,
                .addInstallPackage = addInstallPackage,
                .deinit = deinit,
            },
            .ptr = self,
            .owner = b,
            .phantom = phantom,
        },
    };
    return &self.base;
}

fn addPackage(ctx: *anyopaque, _: *std.Build, options: Sdk.Step.Package.Options) *Sdk.Step.Package {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return Package.create(self, options) catch |e| @panic(@errorName(e));
}

fn addInstallPackage(ctx: *anyopaque, _: *std.Build, pkg: *Sdk.Step.Package) *Sdk.Step.InstallPackage {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return InstallPackage.create(self, pkg) catch |e| @panic(@errorName(e));
}

fn deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.base.owner.allocator.destroy(self);
}
