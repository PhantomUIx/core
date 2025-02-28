const std = @import("std");
const gpu = @import("../gpu.zig");
const Input = @import("Input.zig");
const Output = @import("Output.zig");
const Toplevel = @import("Toplevel.zig");
const Self = @This();

pub const VTable = struct {
    getGpuProvider: *const fn (*anyopaque) anyerror!?*gpu.Provider,
    getInputs: *const fn (*anyopaque) []const Input,
    getOutputs: *const fn (*anyopaque) []const Output,
    getToplevels: *const fn (*anyopaque) []const Toplevel,
    destroy: *const fn (*anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn getGpuProvider(self: *Self) anyerror!?*gpu.Provider {
    return self.vtable.getGpuProvider(self.ptr);
}

pub inline fn getInputs(self: *Self) []const Input {
    return self.vtable.getInputs(self.ptr);
}

pub inline fn getOutputs(self: *Self) []const Output {
    return self.vtable.getOutputs(self.ptr);
}

pub inline fn getToplevels(self: *Self) []const Toplevel {
    return self.vtable.getToplevels(self.ptr);
}

pub inline fn destroy(self: *Self) void {
    return self.vtable.destroy(self.ptr);
}
