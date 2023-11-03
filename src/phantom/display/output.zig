const std = @import("std");
const vizops = @import("vizops");
const Base = @import("base.zig");
const Output = @This();
const Surface = @import("surface.zig");

pub const Info = struct {
    enable: bool = false,
    size: struct {
        phys: vizops.vector.Float32Vector2,
        res: vizops.vector.Vector2(usize),
    },
    scale: vizops.vector.Float32Vector2,
    name: []const u8 = "",
    manufacturer: []const u8 = "",
    depth: u8, // TODO: use depth info from vizops

    pub fn format(self: Info, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s} {{ .enable = {}, .physicalSize = {}x{}mm, .resolution = {}x{}px, .scale = {}x{}%, .name = \"{s}\", .manufacturer = \"{s}\", .depth = {} }}", .{
            @typeName(Info),
            self.enable,
            self.size.phys.value[0],
            self.size.phys.value[1],
            self.size.res.value[0],
            self.size.res.value[1],
            self.scale.value[0],
            self.scale.value[1],
            self.name,
            self.manufacturer,
            self.depth,
        });
    }
};

pub const VTable = struct {
    surfaces: *const fn (*anyopaque) anyerror!std.ArrayList(*Surface),
    createSurface: *const fn (*anyopaque) anyerror!*Surface,
    info: *const fn (*anyopaque) anyerror!Info,
    updateInfo: *const fn (*anyopaque, Info, []std.meta.FieldEnum(Info)) anyerror!void,
    deinit: ?*const fn (*anyopaque) void,
};

vtable: *const VTable,
ptr: *anyopaque,
type: []const u8,
displayKind: Base.Kind,

pub inline fn surfaces(self: *Output) !std.ArrayList(*Surface) {
    return self.vtable.surfaces(self.ptr);
}

pub inline fn createSurface(self: *Output) !*Surface {
    return self.vtable.createSurface(self.ptr);
}

pub inline fn info(self: *Output) !Info {
    return self.vtable.info(self.ptr);
}

pub inline fn updateInfo(self: *Output, val: Info, fields: []std.meta.FieldEnum(Info)) !void {
    return self.vtable.updateInfo(self.ptr, val, fields);
}

pub inline fn deinit(self: *Output) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}

pub fn format(self: *const Output, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;

    try writer.print("{s}@{?s} {{", .{ self.type, std.enums.tagName(Base.Kind, self.displayKind) });

    if (@constCast(self).info() catch null) |outputInfo| {
        try writer.print(" .info = {},", .{outputInfo});
    }

    if (@constCast(self).surfaces() catch null) |surfacesList| {
        try writer.print(" .surfaces = [{}] {{", .{surfacesList.items.len});

        for (surfacesList.items) |surface| {
            try writer.print(" {},", .{surface});
        }

        try writer.writeAll(" },");
    }

    try writer.writeAll(" }");
}
