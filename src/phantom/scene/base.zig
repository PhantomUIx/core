const std = @import("std");
const vizops = @import("vizops");
const GpuSurface = @import("../gpu/surface.zig");
const fb = @import("../painting/fb.zig");
const Node = @import("node.zig");
const Scene = @This();

pub const Target = union(enum) {
    surface: *GpuSurface,
    fb: *fb.Base,
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
    createNode: *const fn (*anyopaque, []const u8, usize, std.StringHashMap(?*anyopaque)) anyerror!*Node,
    preFrame: ?*const fn (*anyopaque, *Node) anyerror!void = null,
    postFrame: ?*const fn (*anyopaque, *Node) anyerror!void = null,
};

allocator: std.mem.Allocator,
vtable: *const VTable,
ptr: *anyopaque,
subscene: ?struct {
    pos: vizops.vector.UsizeVector2,
    size: vizops.vector.UsizeVector2,
} = null,

pub fn sub(self: *Scene, pos: vizops.vector.UsizeVector2, size: vizops.vector.UsizeVector2) Scene {
    return .{
        .allocator = self.allocator,
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

pub inline fn deinit(self: *Scene) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}

pub fn frame(self: *Scene, node: *Node) !bool {
    if (self.vtable.preFrame) |f| try f(self.ptr, node);

    if (try node.preFrame(self.frameInfo(), self)) {
        try node.frame(self);
        try node.postFrame(self);

        if (self.vtable.postFrame) |f| try f(self.ptr, node);
        return true;
    }

    if (self.vtable.postFrame) |f| try f(self.ptr, node);
    return false;
}

pub fn createNode(self: *Scene, T: anytype, args: anytype) !*Node {
    var argsMap = std.StringHashMap(?*anyopaque).init(self.allocator);
    defer argsMap.deinit();

    inline for (@typeInfo(@TypeOf(args)).Struct.fields) |fieldInfo| {
        const field = @field(args, fieldInfo.name);
        switch (@typeInfo(@TypeOf(field))) {
            .Int, .ComptimeInt => try argsMap.put(fieldInfo.name, @ptrFromInt(field)),
            .Float, .ComptimeFloat => try argsMap.put(fieldInfo.name, @ptrFromInt(@as(usize, @bitCast(@as(f64, @floatCast(field)))))),
            .Enum => try argsMap.put(fieldInfo.name, @ptrFromInt(@intFromEnum(field))),
            .Struct => try argsMap.put(fieldInfo.name, @constCast(&field)),
            .Pointer => |p| switch (@typeInfo(p.child)) {
                .Array => {
                    try argsMap.put(fieldInfo.name ++ ".len", @ptrFromInt(field.len));
                    try argsMap.put(fieldInfo.name, @ptrCast(@constCast(field.ptr)));
                },
                else => @compileError("Unsupported type: " ++ @typeName(@TypeOf(field))),
            },
            else => @compileError("Unsupported type: " ++ @typeName(@TypeOf(field))),
        }
    }

    return self.vtable.createNode(self.ptr, @tagName(T), @returnAddress(), argsMap);
}
