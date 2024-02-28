const std = @import("std");

pub const Font = @import("fonts/font.zig");
pub const Format = @import("fonts/format.zig");

pub const backends = @import("fonts/backends.zig");
pub const BackendType = std.meta.DeclEnum(backends);

pub fn Backend(comptime T: BackendType) type {
    return @field(backends, @tagName(T));
}
