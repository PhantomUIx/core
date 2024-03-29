const std = @import("std");
const anyplus = @import("any+");
const vizops = @import("vizops");
const GpuSurface = @import("../gpu/surface.zig");
const fb = @import("../painting/fb.zig");
const sceneModule = @import("../scene.zig");
const Node = @import("node.zig");
const Scene = @This();

pub const Target = union(enum) {
    surface: *GpuSurface,
    fb: *fb.Base,
    any: struct {
        value: anyplus.Anytype,
        deinitFunc: ?*const fn (*const anyplus.Anytype) void = null,

        pub fn deinit(self: *const @This()) void {
            if (self.deinitFunc) |f| f(&self.value);
        }
    },

    pub fn deinit(self: Target) void {
        switch (self) {
            .surface => |s| s.deinit(),
            .fb => |f| f.deinit(),
            .any => |a| a.deinit(),
        }
    }
};

pub const Sub = struct {
    pos: vizops.vector.UsizeVector2,
    size: vizops.vector.UsizeVector2,
};

pub const Options = struct {
    allocator: std.mem.Allocator,
    frame_info: Node.FrameInfo,
    target: ?Target,
};

pub const VTable = struct {
    sub: ?*const fn (*anyopaque, vizops.vector.UsizeVector2, vizops.vector.UsizeVector2) *anyopaque,
    frameInfo: *const fn (*anyopaque) Node.FrameInfo,
    deinit: ?*const fn (*anyopaque) void = null,
    preFrame: ?*const fn (*anyopaque, *Node) anyerror!void = null,
    postFrame: ?*const fn (*anyopaque, *Node, bool) anyerror!void = null,
};

allocator: std.mem.Allocator,
vtable: *const VTable,
type: sceneModule.BackendType,
ptr: *anyopaque,
subscene: ?Sub = null,
seq: u64 = 0,

pub fn sub(self: *Scene, pos: vizops.vector.UsizeVector2, size: vizops.vector.UsizeVector2) Scene {
    return .{
        .allocator = self.allocator,
        .vtable = self.vtable,
        .type = self.type,
        .ptr = if (self.vtable.sub) |f| f(self.ptr, pos, size) else self.ptr,
        .subscene = .{
            .pos = pos,
            .size = size,
        },
    };
}

pub inline fn frameInfo(self: *Scene) Node.FrameInfo {
    return self.vtable.frameInfo(self.ptr).withSequence(self.seq);
}

pub inline fn deinit(self: *Scene) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}

pub fn frame(self: *Scene, node: *Node) !bool {
    if (self.vtable.preFrame) |f| try f(self.ptr, node);

    if (try node.preFrame(self.frameInfo(), self)) {
        self.seq += 1;
        try node.frame(self);
        try node.postFrame(self);

        if (self.vtable.postFrame) |f| try f(self.ptr, node, true);
        return true;
    }

    if (self.vtable.postFrame) |f| try f(self.ptr, node, false);
    return false;
}

pub fn createNode(self: *Scene, comptime NodeType: sceneModule.NodeType, options: sceneModule.NodeOptions(NodeType)) !*Node {
    return sceneModule.createNode(self.type, self.allocator, @returnAddress(), NodeType, options);
}
