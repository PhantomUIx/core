const std = @import("std");
const Output = @import("output.zig");
const Base = @This();

pub const Kind = enum {
    compositor,
    client,
};

pub const VTable = struct {
    outputs: *const fn (*anyopaque) anyerror!std.ArrayList(*Output),
};

vtable: *const VTable,
ptr: *anyopaque,
kind: Kind,
type: []const u8,

pub inline fn outputs(self: *Base) !std.ArrayList(*Output) {
    return self.vtable.outputs(self.ptr);
}

pub fn format(self: *const Base, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;

    try writer.print("{s}@{?s} {{", .{ self.type, std.enums.tagName(Kind, self.kind) });

    if (@constCast(self).outputs() catch null) |outputsList| {
        try writer.print(" .outputs = [{}] {{", .{outputsList.items.len});

        for (outputsList.items) |output| {
            try writer.print(" {},", .{output});
        }

        try writer.writeAll(" }");
    }

    try writer.writeAll(" }");
}
