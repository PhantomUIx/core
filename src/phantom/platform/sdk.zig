const std = @import("std");
const Base = @This();

pub const Step = @import("sdk/step.zig");

pub const VTable = struct {
    addPackage: *const fn (*anyopaque, *std.Build, Step.Package.Options) *Step.Package,
    addInstallPackage: *const fn (*anyopaque, *std.Build, *Step.Package) *Step.InstallPackage,
    deinit: ?*const fn (*anyopaque) void = null,
};

vtable: *const VTable,
ptr: *anyopaque,
owner: *std.Build,
phantom: *std.Build.Module,

pub inline fn addPackage(self: *const Base, options: Step.Package.Options) *Step.Package {
    return self.vtable.addPackage(self.ptr, self.owner, options);
}

pub inline fn addInstallPackage(self: *const Base, pkg: *Step.Package) *Step.InstallPackage {
    return self.vtable.addInstallPackage(self.ptr, self.owner, pkg);
}

pub inline fn deinit(self: *const Base) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}

pub fn installPackage(self: *const Base, pkg: *Step.Package) void {
    self.owner.getInstallStep().dependOn(&self.addInstallPackage(pkg).step);
}
