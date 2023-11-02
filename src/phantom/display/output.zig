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
};

pub const VTable = struct {
    surfaces: *const fn (*anyopaque) anyerror!std.ArrayList(*Surface),
    createSurface: *const fn (*anyopaque) anyerror!*Surface,
    info: *const fn (*anyopaque) anyerror!Info,
    updateInfo: *const fn (*anyopaque, Info, []std.meta.FieldEnum(Info)) anyerror!void,
};

vtable: *const VTable,
ptr: *anyopaque,
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
