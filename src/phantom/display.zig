const std = @import("std");

pub const Base = @import("display/base.zig");
pub const Output = @import("display/output.zig");
pub const Surface = @import("display/surface.zig");

pub const backends = @import("display/backends.zig");
pub const BackendType = std.meta.DeclEnum(backends);

pub fn Backend(comptime T: BackendType) type {
    return @field(backends, @tagName(T));
}
