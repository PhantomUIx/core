const std = @import("std");
const math = @import("../../math.zig");
const graphics = @import("../../graphics.zig");
const Context = @import("../Context.zig");
const Color = @import("../Color.zig");
const zigimg = @import("zigimg");
const Self = @This();

pub const Operation = union(enum) {
    rect: Rect,
    path: Path,
    composite: Composite,
    setTransform: SetTransform,
    clear: Clear,

    pub const Mode = union(enum) {
        fill: void,
        stroke: Stroke,

        pub const Stroke = struct {
            width: f32 = 1.0,
        };
    };

    pub const Rect = struct {
        source: graphics.Source,
        rect: math.Rect(f32),
        border_radius: BorderRadius = .{},
        mode: Mode,

        pub const BorderRadius = struct {
            top_left: ?f32 = null,
            top_right: ?f32 = null,
            bottom_left: ?f32 = null,
            bottom_right: ?f32 = null,

            pub fn all(value: ?f32) BorderRadius {
                return .{
                    .top_left = value,
                    .top_right = value,
                    .bottom_left = value,
                    .bottom_right = value,
                };
            }
        };
    };

    pub const Path = struct {
        value: []const math.Vec2(f32),
        source: graphics.Source,
        mode: Path.Mode,

        pub const Mode = union(enum) {
            fill: void,
            dots: void,
            stroke: Operation.Mode.Stroke,
        };
    };

    pub const Composite = struct {
        source: graphics.Source,
        position: math.Vec2(f32),
        mode: Composite.Mode,

        pub const Mode = enum {
            in,
            over,
        };
    };

    pub const SetTransform = struct {
        value: math.Mat3x3(f32),
    };

    pub const Clear = struct {
        color: graphics.Color,
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
    return .@"2d";
}

fn vtable_destroy(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.vtable.destroy(self.ptr);
}
