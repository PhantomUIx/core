const std = @import("std");

pub const Base = @import("platform/base.zig");

pub const backends = @import("platform/backends.zig");
pub const BackendType = std.meta.DeclEnum(backends);

pub fn Backend(comptime T: BackendType) type {
    return @field(backends, @tagName(T));
}
