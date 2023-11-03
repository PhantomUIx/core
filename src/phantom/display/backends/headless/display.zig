const std = @import("std");
const Allocator = std.mem.Allocator;
const Base = @import("../../base.zig");
const Output = @import("../../output.zig");
const HeadlessOutput = @import("output.zig");
const HeadlessDisplay = @This();

kind: Base.Kind,
outputs: std.ArrayList(*HeadlessOutput),

pub fn init(alloc: Allocator, kind: Base.Kind) HeadlessDisplay {
    return .{
        .kind = kind,
        .outputs = std.ArrayList(*HeadlessOutput).init(alloc),
    };
}

pub fn deinit(self: *HeadlessDisplay) void {
    for (self.outputs.items) |output| @constCast(&output.base).deinit();
    self.outputs.deinit();
}

pub fn display(self: *HeadlessDisplay) Base {
    return .{
        .vtable = &.{
            .outputs = impl_outputs,
        },
        .type = @typeName(HeadlessDisplay),
        .ptr = self,
        .kind = self.kind,
    };
}

pub fn addOutput(self: *HeadlessDisplay, info: Output.Info) !*HeadlessOutput {
    for (self.outputs.items) |output| {
        if (std.mem.eql(u8, output.info.name, info.name)) return error.AlreadyExists;
    }

    const output = try HeadlessOutput.new(self.outputs.allocator, self.kind, info);
    try self.outputs.append(output);
    return output;
}

fn impl_outputs(ctx: *anyopaque) anyerror!std.ArrayList(*Output) {
    const self: *HeadlessDisplay = @ptrCast(@alignCast(ctx));
    var outputs = try std.ArrayList(*Output).initCapacity(self.outputs.allocator, self.outputs.items.len);

    for (self.outputs.items) |output| {
        outputs.appendAssumeCapacity(@constCast(&output.base));
    }

    return outputs;
}
