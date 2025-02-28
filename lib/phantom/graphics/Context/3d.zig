const std = @import("std");
const graphics = @import("../../graphics.zig");
const math = @import("../../math.zig");
const Context = @import("../Context.zig");
const Self = @This();

pub const Operation = union(enum) {
    polygon: Polygon,
    setProjection: SetProjection,
    clear: Clear,

    pub const Polygon = struct {
        vertices: []math.Vec4(f32),
        indices: []usize,
        view: math.Mat4x4(f32),
        model: math.Mat4x4(f32),
        source: graphics.Source,
    };

    pub const SetProjection = struct {
        value: math.Mat4x4(f32),
    };

    pub const Clear = struct {
        color: ?graphics.Color,
        depth: ?Depth,

        pub const Depth = union(enum) {
            zbuffer: void,
            culling: void,
            none: void,
        };
    };
};

pub const VTable = struct {
    getSize: *const fn (self: *anyopaque) math.Vec2(usize),
    render: *const fn (self: *anyopaque, op: Operation) anyerror!void,
    destroy: *const fn (self: *anyopaque) void,
};

pub const context_vtable: Context.VTable = .{
    .getSize = vtable_getSize,
    .getKind = vtable_getKind,
    .destroy = vtable_destroy,
};

base: Context,
ptr: *anyopaque,
vtable: *const VTable,

pub inline fn init(self: *Self, ptr: *anyopaque, vtable: *const VTable) Self {
    return .{
        .base = .{
            .ptr = self,
            .vtable = &context_vtable,
        },
        .ptr = ptr,
        .vtable = vtable,
    };
}

pub inline fn getSize(self: *Self) math.Vec2(usize) {
    return self.vtable.getSize(self.ptr);
}

pub inline fn render(self: *Self, op: Operation) anyerror!void {
    return self.vtable.render(self.ptr, op);
}

pub inline fn destroy(self: *const Self) void {
    return self.vtable.destroy(self.ptr);
}

fn vtable_getSize(ctx: *anyopaque) math.Vec2(usize) {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.getSize();
}

fn vtable_getKind(_: *anyopaque) Context.Kind {
    return .@"3d";
}

fn vtable_destroy(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.vtable.destroy(self.ptr);
}
