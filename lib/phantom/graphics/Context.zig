const std = @import("std");
const assert = std.debug.assert;
const math = @import("../math.zig");
const Context = @This();

pub const @"2d" = @import("Context/2d.zig");
pub const @"3d" = @import("Context/3d.zig");

pub const Operation = union(Kind) {
    @"2d": @"2d".Operation,
    @"3d": @"3d".Operation,
};

pub const StateOperation = union(enum) {
    save: *?*anyopaque,
    load: *anyopaque,
    clear: void,
};

pub const Kind = enum {
    @"2d",
    @"3d",

    pub fn Type(comptime self: Kind) type {
        return switch (self) {
            .@"2d" => Context.@"2d",
            .@"3d" => Context.@"3d",
        };
    }
};

pub const Error = std.mem.Allocator.Error || error{
    InvalidKind,
    Unknown,
};

pub const VTable = struct {
    getSize: *const fn (self: *anyopaque) math.Vec2(usize),
    getKind: *const fn (self: *anyopaque) Kind,
    destroy: *const fn (self: *anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn getSize(self: *const Context) math.Vec2(usize) {
    return self.vtable.getSize(self.ptr);
}

pub inline fn getKind(self: *const Context) Kind {
    return self.vtable.getKind(self.ptr);
}

pub inline fn destroy(self: *const Context) void {
    return self.vtable.destroy(self.ptr);
}

pub fn as(self: *const Context, comptime kind: Kind) *kind.Type() {
    assert(self.getKind() == kind);
    return @ptrCast(@alignCast(self.ptr));
}

pub fn render(self: *Context, op: Operation) !void {
    if (op != self.getKind()) return error.InvalidOperation;
    return switch (op) {
        .@"2d" => |a| self.as(.@"2d").render(a),
        .@"3d" => |b| self.as(.@"3d").render(b),
    };
}
