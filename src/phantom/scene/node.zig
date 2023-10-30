const std = @import("std");
const vizops = @import("vizops");
const Scene = @import("base.zig");
const Node = @This();

pub const FrameInfo = struct {
    size: struct {
        phys: vizops.vector.Vector2(usize),
        res: vizops.vector.Vector2(usize),
        avail: vizops.vector.Vector2(usize),
    },
    scale: vizops.vector.Float32Vector2,
    depth: u8,

    pub fn equal(self: FrameInfo, other: FrameInfo) bool {
        return std.simd.countTrues(@Vector(4, bool){
            std.simd.countTrues(self.size.phys.value == other.size.phys.value) == 2,
            std.simd.countTrues(self.size.res.value == other.size.res.value) == 2,
            std.simd.countTrues(self.size.avail.value == other.size.avail.value) == 2,
            std.simd.countTrues(self.scale.value == other.scale.value) == 2,
            self.depth == other.depth,
        }) == 4;
    }

    pub fn child(self: FrameInfo, availSize: vizops.vector.Vector2(usize)) FrameInfo {
        return .{ .size = .{
            .phys = self.size.phys,
            .res = self.size.res,
            .avail = availSize,
        }, .scale = self.scale, .depth = self.depth };
    }
};

pub const VTable = struct {
    dupe: *const fn (*anyopaque) anyerror!*anyopaque,
    state: *const fn (*anyopaque, FrameInfo) anyerror!State,
    preFrame: *const fn (*anyopaque, FrameInfo, *Scene) anyerror!State,
    frame: *const fn (*anyopaque, *Scene) anyerror!void,
    postFrame: ?*const fn (*anyopaque, *Scene) anyerror!void = null,
    format: ?*const fn (*anyopaque, comptime []const u8, std.fmt.FormatOptions, anytype) anyerror!void = null,
    deinit: ?*const fn (*anyopaque) void = null,
};

pub const State = struct {
    size: vizops.vector.Vector2(usize),
    frame_info: FrameInfo,
    ptr: ?*anyopaque = null,
    allocator: ?std.mem.Allocator = null,
    ptrEqual: ?*const fn (*anyopaque, *anyopaque) bool = null,
    ptrFree: ?*const fn (*anyopaque, std.mem.Allocator) void,

    pub inline fn deinit(self: State, alloc: ?std.mem.Allocator) void {
        return if (self.ptrFree) |f| f(self.ptr, (self.allocator orelse alloc).?);
    }

    pub fn equal(self: State, other: State) bool {
        return std.simd.countTrues(@Vector(4, bool){
            std.simd.countTrues(self.size.value == other.size.value) == 2,
            self.frameInfo.equal(other.frame_info),
            self.ptr == other.ptr,
            if (self.ptrEqual) |f| f(self.ptr.?, self.ptr.?) else true,
        }) == 4;
    }
};

vtable: *const VTable,
ptr: *anyopaque,
last_state: ?State = null,

pub inline fn dupe(self: *Node) anyerror!*anyopaque {
    return self.vtable.dupe(self.ptr);
}

pub inline fn state(self: *Node, frameInfo: FrameInfo) anyerror!State {
    return if (self.last_state) |s| s else self.vtable.state(self.ptr, frameInfo);
}

pub fn preFrame(self: *Node, frameInfo: FrameInfo, scene: *Scene) anyerror!bool {
    const newState = try self.vtable.preFrame(self.ptr, frameInfo, scene);
    const shouldApply = !(if (self.last_state) |lastState| lastState.equal(newState) else false);

    if (shouldApply) {
        if (self.last_state) |l| l.deinit();

        self.last_state = newState;
    }
    return shouldApply;
}

pub inline fn frame(self: *Node, scene: *Scene) anyerror!void {
    return if (self.lastState != null) self.vtable.frame(self.ptr, scene) else void;
}

pub inline fn postFrame(self: *Node, scene: *Scene) anyerror!void {
    return if (self.lastState != null) (if (self.vtable.postFrame) |f| f(self.ptr, scene) else void) else void;
}

pub inline fn format(self: *Node, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    return if (self.vtable.format) |f| f(self.ptr, fmt, options, writer) else void;
}

pub inline fn deinit(self: *Node) void {
    if (self.last_state) |l| l.deinit(null);
    return if (self.vtable.deinit) |f| f(self.ptr) else void;
}
