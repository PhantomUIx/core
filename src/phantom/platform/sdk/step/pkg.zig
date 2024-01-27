const std = @import("std");
const Sdk = @import("../../sdk.zig");
const Self = @This();

pub const Kind = enum { application };

pub const Options = struct {
    id: []const u8,
    name: []const u8,
    root_module: std.Build.Module.CreateOptions,
    kind: Kind,
    version: std.SemanticVersion,
};

sdk: *Sdk,
step: std.Build.Step,
id: []const u8,
name: []const u8,
output_file: std.Build.GeneratedFile,
kind: Kind,
root_module: *std.Build.Module,

pub fn init(self: *Self, sdk: *Sdk, options: Options, makeFn: std.Build.Step.MakeFn, root_module: *std.Build.Module) void {
    const b = sdk.owner;

    self.* = .{
        .sdk = sdk,
        .step = std.Build.Step.init(.{
            .id = .custom,
            .name = b.fmt("Package {s} (id: {s})", .{ options.name, options.id }),
            .owner = b,
            .makeFn = makeFn,
        }),
        .id = options.id,
        .name = options.name,
        .output_file = .{ .step = &self.step },
        .kind = options.kind,
        .root_module = root_module,
    };
}
