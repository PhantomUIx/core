const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const Base = @import("../../base.zig");
const Output = @import("../../output.zig");
const Surface = @import("../../surface.zig");
const HeadlessOutput = @This();

base: Output,
allocator: Allocator,
info: Output.Info,

pub fn new(alloc: Allocator, displayKind: Base.Kind, info: Output.Info) Allocator.Error!*HeadlessOutput {
    const self = try alloc.create(HeadlessOutput);
    errdefer alloc.destroy(self);

    self.* = .{
        .base = .{
            .ptr = self,
            .vtable = &.{
                .surfaces = impl_surfaces,
                .createSurface = impl_create_surface,
                .info = impl_info,
                .updateInfo = impl_update_info,
                .deinit = impl_deinit,
            },
            .displayKind = displayKind,
            .type = @typeName(HeadlessOutput),
        },
        .allocator = alloc,
        .info = info,
    };
    return self;
}

pub fn dupe(self: *HeadlessOutput) Allocator.Error!*HeadlessOutput {
    const d = try self.allocator.create(HeadlessOutput);
    errdefer self.allocator.destroy(d);

    d.* = .{
        .base = .{
            .ptr = self,
            .vtable = self.base.vtable,
            .displayKind = self.base.displayKind,
            .type = @typeName(HeadlessOutput),
        },
        .allocator = self.allocator,
        .info = self.info,
    };
    return d;
}

fn impl_surfaces(ctx: *anyopaque) anyerror!std.ArrayList(*Surface) {
    const self: *HeadlessOutput = @ptrCast(@alignCast(ctx));
    return std.ArrayList(*Surface).init(self.allocator);
}

fn impl_create_surface(_: *anyopaque) anyerror!*Surface {
    return error.NotImplemented;
}

fn impl_info(ctx: *anyopaque) anyerror!Output.Info {
    const self: *HeadlessOutput = @ptrCast(@alignCast(ctx));
    return self.info;
}

fn impl_update_info(_: *anyopaque, info: Output.Info, fields: []std.meta.FieldEnum(Output.Info)) anyerror!void {
    _ = info;
    _ = fields;
    return error.NotImplemented;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *HeadlessOutput = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}
