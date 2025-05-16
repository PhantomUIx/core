const std = @import("std");
const Self = @This();

pub const VTable = struct {
    destroy: *const fn (*anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn destroy(self: *Self) void {
    return self.vtable.destroy(self.ptr);
}
