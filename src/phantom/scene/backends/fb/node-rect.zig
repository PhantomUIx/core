const std = @import("std");
const Allocator = std.mem.Allocator;
const anyplus = @import("any+");
const vizops = @import("vizops");
const math = @import("../../../math.zig");
const Scene = @import("../../base.zig");
const Node = @import("../../node.zig");
const FrameBufferScene = @import("scene.zig");
const NodeRect = @This();

const RadiusSide = struct {
    left: ?f32,
    right: ?f32,

    pub fn equal(self: RadiusSide, other: RadiusSide) bool {
        return std.simd.countTrues(@Vector(2, bool){
            self.left == other.left,
            self.right == other.right,
        }) == 2;
    }
};

const Radius = struct {
    top: ?RadiusSide,
    bottom: ?RadiusSide,

    pub fn equal(self: Radius, other: Radius) bool {
        return std.simd.countTrues(@Vector(2, bool){
            if (self.top == null and other.top != null) false else if (self.top != null and other.top == null) false else self.top.?.equal(other.top.?),
            if (self.bottom == null and other.bottom != null) false else if (self.bottom != null and other.bottom == null) false else self.bottom.?.equal(other.bottom.?),
        }) == 2;
    }
};

pub const Options = struct {
    radius: ?Radius,
    size: vizops.vector.Float32Vector2,
    color: vizops.color.Any,
};

const State = struct {
    radius: ?Radius,
    color: vizops.color.Any,

    pub fn init(alloc: Allocator, options: Options) Allocator.Error!*State {
        const self = try alloc.create(State);
        self.* = .{
            .radius = options.radius,
            .color = options.color,
        };
        return self;
    }

    pub fn equal(self: *State, other: *State) bool {
        return std.simd.countTrues(@Vector(2, bool){
            if (self.radius == null and other.radius != null) false else if (self.radius != null and other.radius == null) false else self.radius.?.equal(other.radius.?),
            self.color.equal(other.color),
        }) == 2;
    }

    pub fn deinit(self: *State, alloc: Allocator) void {
        alloc.destroy(self);
    }
};

options: Options,
node: Node,

pub fn create(id: ?usize, args: std.StringHashMap(anyplus.Anytype)) !*Node {
    const size = try (args.get("size") orelse return error.MissingKey).cast(vizops.vector.Float32Vector2);
    const color = try (args.get("color") orelse return error.MissingKey).cast(vizops.color.Any);
    return &(try new(args.allocator, id orelse @returnAddress(), .{
        .size = vizops.vector.Float32Vector2.init(size.value),
        .color = color,
        .radius = .{
            .top = .{
                .left = if (args.get("topLeft")) |v| try v.cast(f32) else null,
                .right = if (args.get("topRight")) |v| try v.cast(f32) else null,
            },
            .bottom = .{
                .left = if (args.get("bottomLeft")) |v| try v.cast(f32) else null,
                .right = if (args.get("bottomRight")) |v| try v.cast(f32) else null,
            },
        },
    })).node;
}

pub fn new(alloc: Allocator, id: ?usize, options: Options) Allocator.Error!*NodeRect {
    const self = try alloc.create(NodeRect);
    errdefer alloc.destroy(self);

    self.* = .{
        .options = options,
        .node = .{
            .allocator = alloc,
            .ptr = self,
            .type = @typeName(NodeRect),
            .id = id orelse @returnAddress(),
            .vtable = &.{
                .dupe = dupe,
                .state = state,
                .preFrame = preFrame,
                .frame = frame,
                .deinit = deinit,
                .format = format,
                .setProperties = setProperties,
            },
        },
    };
    return self;
}

fn stateEqual(ctx: *anyopaque, otherctx: *anyopaque) bool {
    const self: *State = @ptrCast(@alignCast(ctx));
    const other: *State = @ptrCast(@alignCast(otherctx));
    return self.equal(other);
}

fn stateFree(ctx: *anyopaque, alloc: std.mem.Allocator) void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.deinit(alloc);
}

fn dupe(ctx: *anyopaque) anyerror!*Node {
    const self: *NodeRect = @ptrCast(@alignCast(ctx));
    return &(try new(self.node.allocator, @returnAddress(), self.options)).node;
}

fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!Node.State {
    const self: *NodeRect = @ptrCast(@alignCast(ctx));
    return .{
        .size = math.rel(frameInfo, self.options.size),
        .frame_info = frameInfo,
        .allocator = self.node.allocator,
        .ptr = try State.init(self.node.allocator, self.options),
        .ptrEqual = stateEqual,
        .ptrFree = stateFree,
        .type = @typeName(NodeRect),
    };
}

fn preFrame(ctx: *anyopaque, frameInfo: Node.FrameInfo, _: *Scene) anyerror!Node.State {
    const self: *NodeRect = @ptrCast(@alignCast(ctx));
    return .{
        .size = math.rel(frameInfo, self.options.size),
        .frame_info = frameInfo,
        .allocator = self.node.allocator,
        .ptr = try State.init(self.node.allocator, self.options),
        .ptrEqual = stateEqual,
        .ptrFree = stateFree,
        .type = @typeName(NodeRect),
    };
}

fn frame(ctx: *anyopaque, baseScene: *Scene) anyerror!void {
    const self: *NodeRect = @ptrCast(@alignCast(ctx));
    const scene: *FrameBufferScene = @ptrCast(@alignCast(baseScene.ptr));

    const size = (try self.node.state(baseScene.frameInfo())).size;
    const pos: vizops.vector.UsizeVector2 = if (baseScene.subscene) |sub| sub.pos else .{};

    const bufferInfo = scene.buffer.info();

    const buffer = try self.node.allocator.alloc(u8, @divExact(bufferInfo.colorFormat.width(), 8));
    defer self.node.allocator.free(buffer);
    try vizops.color.writeAnyBuffer(bufferInfo.colorFormat, buffer, self.options.color);

    const stride = buffer.len * bufferInfo.res.value[0];

    var y: usize = 0;
    // TODO: handle corners
    while (y < size.value[1]) : (y += 1) {
        var x: usize = 0;
        while (x < size.value[0]) : (x += 1) {
            const i = ((y + pos.value[1]) * stride) + ((x + pos.value[0]) * buffer.len);
            try scene.buffer.write(i, buffer);
        }
    }
}

fn deinit(ctx: *anyopaque) void {
    const self: *NodeRect = @ptrCast(@alignCast(ctx));
    self.node.allocator.destroy(self);
}

fn format(ctx: *anyopaque, _: ?Allocator) anyerror!std.ArrayList(u8) {
    const self: *NodeRect = @ptrCast(@alignCast(ctx));

    var output = std.ArrayList(u8).init(self.node.allocator);
    errdefer output.deinit();

    try output.writer().print("{{ .size = {}, .color = {}", .{ self.options.size, self.options.color });

    if (self.options.radius) |r| {
        if (r.top) |t| {
            if (t.left) |v| try output.writer().print(", .topLeft = {}", .{v});
            if (t.right) |v| try output.writer().print(", .topRight = {}", .{v});
        }
        if (r.top) |b| {
            if (b.left) |v| try output.writer().print(", .bottomLeft = {}", .{v});
            if (b.right) |v| try output.writer().print(", .bottomRight = {}", .{v});
        }
    }

    try output.writer().writeAll(" }");
    return output;
}

fn setProperties(ctx: *anyopaque, args: std.StringHashMap(anyplus.Anytype)) anyerror!void {
    const self: *NodeRect = @ptrCast(@alignCast(ctx));

    var iter = args.iterator();
    while (iter.next()) |entry| {
        const key = entry.key_ptr.*;

        if (std.mem.eql(u8, key, "size")) {
            self.options.size = try entry.value_ptr.cast(vizops.vector.Float32Vector2);
        } else if (std.mem.eql(u8, key, "color")) {
            self.options.color = try entry.value_ptr.cast(vizops.color.Any);
        } else return error.InvalidKey;
    }
}
