const std = @import("std");
const metaplus = @import("meta+");

const base = struct {
    pub const NodeTree = @import("scene/node-tree.zig");
    pub const NodeFlex = @import("scene/node-flex.zig");
    pub const NodeStack = @import("scene/node-stack.zig");
};

pub const Base = @import("scene/base.zig");
pub const Node = @import("scene/node.zig");
pub usingnamespace base;

pub const nodes = @import("scene/nodes.zig");
pub const backends = @import("scene/backends.zig");
pub const BackendType = metaplus.enums.fromDecls(backends);
pub const NodeType = metaplus.enums.fields.mix(std.meta.DeclEnum(base), std.meta.DeclEnum(nodes));

pub fn NodeOptions(comptime T: NodeType) type {
    return @field(struct {
        pub usingnamespace base;
        pub usingnamespace nodes;
    }, @tagName(T)).Options;
}

pub fn Backend(comptime T: BackendType) type {
    return struct {
        pub usingnamespace @field(backends, @tagName(T));
        pub const Node = @import("scene/node.zig");
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

pub fn createNode(backendType: BackendType, alloc: std.mem.Allocator, id: ?usize, comptime nodeType: NodeType, options: NodeOptions(nodeType)) !*Node {
    const tag = std.enums.tagName(BackendType, backendType) orelse return error.InvalidBackend;
    inline for (@typeInfo(backends).Struct.decls) |decl| {
        if (std.mem.eql(u8, decl.name, tag)) {
            const backend = Backend(@field(BackendType, decl.name));
            return @field(backend, @tagName(nodeType)).new(alloc, id, options);
        }
    }
    return error.InvalidBackend;
}
