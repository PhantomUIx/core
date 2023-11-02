const std = @import("std");
const Output = @import("output.zig");
const Base = @This();

pub const Kind = enum {
    compositor,
    client,
};

pub const VTable = struct {
    outputs: *const fn (*anyopaque) std.ArrayList(*Output),
};

vtable: *const VTable,
ptr: *anyopaque,
kind: Kind,

pub inline fn outputs(self: *Base) std.ArrayList(*Output) {
    return self.vtable.outputs(self.ptr);
}
