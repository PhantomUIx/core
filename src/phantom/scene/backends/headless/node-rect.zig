const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const math = @import("../../../math.zig");
const Scene = @import("../../base.zig");
const Node = @import("../../node.zig");
const NodeRect = @This();

const RadiusSide = struct {
    left: ?f32,
    right: ?f32,
};

const RadiusEdge = struct {
    top: ?RadiusSide,
    bottom: ?RadiusSide,
};

pub const Options = struct {
    radius: ?RadiusEdge,
    size: vizops.vector.Float32Vector2,
    color: vizops.vector.Float32Vector4,
};

allocator: Allocator,
options: Options,
node: Node,

pub fn create(args: std.StringHashMap(?*anyopaque)) !*Node {
    _ = args;
    unreachable;
}

pub fn new(alloc: Allocator, id: ?usize, options: Options) Allocator.Error!*NodeRect {
    const self = try alloc.create(NodeRect);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .options = options,
        .node = .{
            .ptr = self,
            .type = @typeName(NodeRect),
            .id = id orelse @returnAddress(),
            .vtable = &.{},
        },
    };
    return self;
}
