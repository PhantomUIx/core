const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const Base = @import("../../base.zig");
const Output = @import("../../output.zig");
const Surface = @import("../../surface.zig");
const HeadlessSurface = @import("surface.zig");
const HeadlessOutput = @This();

base: Output,
info: Output.Info,
surfaces: std.ArrayList(*HeadlessSurface),

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
        .info = info,
        .surfaces = std.ArrayList(*HeadlessSurface).init(alloc),
    };
    return self;
}

pub fn dupe(self: *HeadlessOutput) Allocator.Error!*HeadlessOutput {
    const d = try self.surfaces.allocator.create(HeadlessOutput);
    errdefer self.surfaces.allocator.destroy(d);

    d.* = .{
        .base = .{
            .ptr = self,
            .vtable = self.base.vtable,
            .displayKind = self.base.displayKind,
            .type = @typeName(HeadlessOutput),
        },
        .info = self.info,
        .surfaces = try std.ArrayList(*HeadlessSurface).initCapacity(self.surfaces.allocator, self.surfaces.items.len),
    };
    errdefer d.surfaces.deinit();

    for (self.surfaces.items) |surface| {
        d.surfaces.appendAssumeCapacity(try surface.dupe());
    }
    return d;
}

fn impl_surfaces(ctx: *anyopaque) anyerror!std.ArrayList(*Surface) {
    const self: *HeadlessOutput = @ptrCast(@alignCast(ctx));
    var surfaces = try std.ArrayList(*Surface).initCapacity(self.surfaces.allocator, self.surfaces.items.len);
    errdefer surfaces.deinit();

    for (self.surfaces.items) |surface| {
        surfaces.appendAssumeCapacity(@constCast(&surface.base));
    }
    return surfaces;
}

fn impl_create_surface(ctx: *anyopaque, kind: Surface.Kind, info: Surface.Info) anyerror!*Surface {
    const self: *HeadlessOutput = @ptrCast(@alignCast(ctx));

    const surface = try HeadlessSurface.new(self.surfaces.allocator, self.base.displayKind, kind, info);
    surface.output = self;
    surface.id = self.surfaces.items.len;

    try self.surfaces.append(surface);
    return &surface.base;
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
    const alloc = self.surfaces.allocator;
    for (self.surfaces.items) |surface| @constCast(&surface.base).deinit();
    self.surfaces.deinit();
    alloc.destroy(self);
}
