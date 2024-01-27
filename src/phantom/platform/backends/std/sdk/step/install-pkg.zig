const std = @import("std");
const Package = @import("../../../../sdk/step/pkg.zig");
const InstallPackage = @import("../../../../sdk/step/install-pkg.zig");
const Sdk = @import("../../sdk.zig");
const Self = @This();

base: InstallPackage,
install: *std.Build.Step.InstallArtifact,

pub fn create(sdk: *Sdk, pkg: *Package) !*InstallPackage {
    const b = sdk.base.owner;
    const self = try b.allocator.create(Self);
    errdefer b.allocator.free(self);

    self.base.init(&sdk.base, pkg, make);

    const compile = @fieldParentPtr(@import("pkg.zig"), "base", pkg).compile;
    self.install = b.addInstallArtifact(compile, .{});
    self.base.step.dependOn(&self.install.step);

    return &self.base;
}

fn make(step: *std.Build.Step, _: *std.Progress.Node) !void {
    _ = step;
}
