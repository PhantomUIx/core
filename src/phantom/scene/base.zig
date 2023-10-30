const vizops = @import("vizops");
const Node = @import("node.zig");
const Scene = @This();

pub const VTable = struct {
    sub: ?*const fn (*anyopaque, vizops.vector.Vector2(usize), vizops.vector.Vector2(usize)) *anyopaque,
    frameInfo: *const fn (*anyopaque) Node.FrameInfo,
};

vtable: *const VTable,
ptr: *anyopaque,
subscene: ?struct {
    pos: vizops.vector.Vector2(usize) = null,
    size: vizops.vector.Vector2(usize) = null,
},

pub fn sub(self: *Scene, pos: vizops.vector.Vector2(usize), size: vizops.vector.Vector2(usize)) Scene {
    return .{
        .vtable = self.vtable,
        .ptr = if (self.vtable.sub) |f| f(self.ptr, pos, size) else self.ptr,
        .subscene = .{
            .pos = pos,
            .size = size,
        },
    };
}

pub inline fn frameInfo(self: *Scene) Node.FrameInfo {
    return self.vtable.frameInfo(self.ptr);
}

pub fn frame(self: *Scene, node: *Node) !bool {
    if (try node.preFrame(self.frameInfo(), self)) {
        try node.frame(self);
        try node.postFrame(self);
        return true;
    }
    return false;
}
