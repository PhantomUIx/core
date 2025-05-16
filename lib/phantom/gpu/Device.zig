const std = @import("std");
const Connector = @import("Connector.zig");
const Self = @This();

pub const VTable = struct {
    getConnectors: *const fn (*anyopaque) anyerror![]*Connector,
    destroy: *const fn (*anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn getConnectors(self: *Self) anyerror![]*Connector {
    return self.vtable.getConnectors(self.ptr);
}

pub inline fn destroy(self: *Self) void {
    return self.vtable.destroy(self.ptr);
}
