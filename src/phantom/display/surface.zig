const std = @import("std");
const vizops = @import("vizops");
const Scene = @import("../scene/base.zig");
const Base = @import("base.zig");
const Surface = @This();

pub const Kind = enum {
    output,
    popup,
    view,
};

pub const State = enum {
    minimize,
    maximize,
    fullscreen,
    resizing,
    activated,
};

pub const Info = struct {
    appId: ?[]const u8 = null,
    title: ?[]const u8 = null,
    class: ?[]const u8 = null,
    toplevel: bool = false,
    states: []State = &.{},
    size: vizops.vector.Vector2(usize) = vizops.vector.Vector2(usize).zero(),
    maxSize: vizops.vector.Vector2(usize) = vizops.vector.Vector2(usize).zero(),
    minSize: vizops.vector.Vector2(usize) = vizops.vector.Vector2(usize).zero(),
};

pub const VTable = struct {
    deinit: ?*const fn (*anyopaque) void = null,
    destroy: *const fn (*anyopaque) anyerror!void,
    info: *const fn (*anyopaque) anyerror!Info,
    updateInfo: *const fn (*anyopaque, Info, []std.meta.FieldEnum(Info)) anyerror!void,
    createScene: *const fn (*anyopaque) anyerror!*Scene,
};

vtable: *const VTable,
ptr: *anyopaque,
displayKind: Base.Kind,
kind: Kind,

pub inline fn deinit(self: *Surface) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}

pub inline fn destroy(self: *Surface) !void {
    return self.vtable.destroy(self.ptr);
}

pub inline fn info(self: *Surface) !Info {
    return self.vtable.info(self.ptr);
}

pub inline fn updateInfo(self: *Surface, val: Info, fields: []std.meta.FieldEnum(Info)) !void {
    return self.vtable.updateInfo(self.ptr, val, fields);
}

pub inline fn createScene(self: *Surface) !*Scene {
    return self.vtable.createScene(self.ptr);
}
