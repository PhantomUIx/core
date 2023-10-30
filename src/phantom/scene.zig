const metaplus = @import("meta+");

pub const Base = @import("scene/base.zig");
pub const Node = @import("scene/node.zig");
pub const NodeTree = @import("scene/node-tree.zig");

pub const backends = @import("scene/backends.zig");
pub const BackendType = metaplus.enums.fromDecls(backends);

pub fn Backend(comptime T: BackendType) type {
    return @field(backends, @tagName(T));
}
