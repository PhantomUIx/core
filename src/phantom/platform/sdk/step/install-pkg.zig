const std = @import("std");
const Sdk = @import("../../sdk.zig");
const Package = @import("pkg.zig");
const Self = @This();

sdk: *Sdk,
step: std.Build.Step,
package: *Package,

pub fn init(self: *Self, sdk: *Sdk, pkg: *Package, makeFn: std.Build.Step.MakeFn) void {
    const b = sdk.owner;

    self.* = .{
        .sdk = sdk,
        .step = std.Build.Step.init(.{
            .id = .custom,
            .name = b.fmt("Install package {s} (id: {s})", .{ pkg.name, pkg.id }),
            .owner = b,
            .makeFn = makeFn,
        }),
        .package = pkg,
    };

    self.step.dependOn(&pkg.step);
}
