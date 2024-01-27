const std = @import("std");
const Base = @This();

pub const Step = @import("sdk/step.zig");

pub const VTable = struct {
    addPackage: *const fn (*anyopaque, *std.Build, Step.Package.Options) *Step.Package,
    deinit: ?*const fn (*anyopaque) void = null,
};

vtable: *const VTable,
ptr: *anyopaque,
owner: *std.Build,

pub fn addPackage(self: *const Base, options: Step.Package.Options) *Step.Package {
    return self.vtable.addPackage(self.ptr, self.owner, options);
}

pub fn deinit(self: *const Base) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
