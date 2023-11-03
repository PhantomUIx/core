const std = @import("std");
const metaplus = @import("meta+");

const base = struct {
    pub const Node = @import("scene/node.zig");
    pub const NodeTree = @import("scene/node-tree.zig");
    pub const NodeFlex = @import("scene/node-flex.zig");
};

pub const Base = @import("scene/base.zig");
pub usingnamespace base;

pub const backends = @import("scene/backends.zig");
pub const BackendType = metaplus.enums.fromDecls(backends);

pub fn Backend(comptime T: BackendType) type {
    return struct {
        pub usingnamespace @field(backends, @tagName(T));
        pub usingnamespace base;
    };
}

pub fn createBackend(t: BackendType, options: Base.Options) !*Base {
    const tag = std.enums.tagName(BackendType, t) orelse return error.InvalidBackend;
    inline for (@typeInfo(backends).Struct.decls) |decl| {
        if (std.mem.eql(u8, decl.name, tag)) {
            const backend = Backend(@field(BackendType, decl.name));
            return &(try backend.Scene.new(options)).base;
        }
    }
    return error.InvalidBackend;
}
