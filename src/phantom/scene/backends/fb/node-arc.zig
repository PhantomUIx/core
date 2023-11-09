const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const math = @import("../../../math.zig");
const Scene = @import("../../base.zig");
const Node = @import("../../node.zig");
const NodeArc = @This();

pub const Options = struct {
    radius: f32,
    angles: vizops.vector.Float32Vector2,
    color: vizops.vector.Float32Vector4,
};

const State = struct {
    color: vizops.vector.Float32Vector4,

    pub fn init(alloc: Allocator, options: Options) Allocator.Error!*State {
        const self = try alloc.create(State);
        self.* = .{
            .color = options.color,
        };
        return self;
    }

    pub fn equal(self: *State, other: *State) bool {
        return std.simd.countTrues(self.color.value == other.color.value) == 4;
    }

    pub fn deinit(self: *State, alloc: Allocator) void {
        alloc.destroy(self);
    }
};

allocator: Allocator,
options: Options,
node: Node,

pub fn create(id: ?usize, args: std.StringHashMap(?*anyopaque)) !*Node {
    const radius: f32 = @floatCast(@as(f64, @bitCast(@intFromPtr(args.get("radius") orelse return error.MissingKey))));
    const angles: *vizops.vector.Float32Vector2 = @ptrCast(@alignCast(args.get("angles") orelse return error.MissingKey));
    const color: *vizops.vector.Float32Vector4 = @ptrCast(@alignCast(args.get("color") orelse return error.MissingKey));
    return &(try new(args.allocator, id orelse @returnAddress(), .{
        .radius = radius,
        .angles = vizops.vector.Float32Vector2.init(angles.value),
        .color = vizops.vector.Float32Vector4.init(color.value),
    })).node;
}

pub fn new(alloc: Allocator, id: ?usize, options: Options) Allocator.Error!*NodeArc {
    const self = try alloc.create(NodeArc);
    self.* = .{
        .allocator = alloc,
        .options = options,
        .node = .{
            .ptr = self,
            .type = @typeName(NodeArc),
            .id = id orelse @returnAddress(),
            .vtable = &.{
                .dupe = dupe,
                .state = state,
                .preFrame = preFrame,
                .frame = frame,
                .deinit = deinit,
                .format = format,
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

fn calcSize(self: *NodeArc) vizops.vector.Float32Vector2 {
    const endpoint1 = vizops.vector.Float32Vector2.init([_]f32{
        self.options.radius * std.math.cos(self.options.angles.value[0]),
        self.options.radius * std.math.sin(self.options.angles.value[0]),
    });

    const endpoint2 = vizops.vector.Float32Vector2.init([_]f32{
        self.options.radius * std.math.cos(self.options.angles.value[1]),
        self.options.radius * std.math.sin(self.options.angles.value[1]),
    });

    var max = endpoint1.max(endpoint2);
    var min = endpoint1.min(endpoint2);

    if ((self.options.angles.value[0] <= 0 and self.options.angles.value[1] >= 0) or
        (self.options.angles.value[0] <= 2 * std.math.pi and self.options.angles.value[1] >= 2 * std.math.pi))
    {
        max.value[0] = @max(max.value[0], self.options.radius);
    }

    if (self.options.angles.value[0] <= std.math.pi and self.options.angles.value[1] >= std.math.pi) {
        min.value[0] = @min(min.value[0], -self.options.radius);
    }

    const halfPi = @as(f32, std.math.pi) / 2;
    if ((self.options.angles.value[0] <= halfPi and self.options.angles.value[1] >= halfPi) or
        (self.options.angles.value[0] <= 3 * halfPi and self.options.angles.value[1] >= 3 * halfPi))
    {
        max.value[1] = @max(max.value[1], self.options.radius);
    }

    if (self.options.angles.value[0] <= 3 * halfPi and self.options.angles.value[1] >= 3 * halfPi) {
        min.value[1] = @min(min.value[1], -self.options.radius);
    }

    return max.sub(min);
}

fn dupe(ctx: *anyopaque) anyerror!*Node {
    const self: *NodeArc = @ptrCast(@alignCast(ctx));
    return &(try new(self.allocator, @returnAddress(), self.options)).node;
}

fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!Node.State {
    const self: *NodeArc = @ptrCast(@alignCast(ctx));
    return .{
        .size = math.rel(frameInfo, calcSize(self)),
        .frame_info = frameInfo,
        .allocator = self.allocator,
        .ptr = try State.init(self.allocator, self.options),
        .ptrEqual = stateEqual,
        .ptrFree = stateFree,
    };
}

fn preFrame(ctx: *anyopaque, frameInfo: Node.FrameInfo, _: *Scene) anyerror!Node.State {
    const self: *NodeArc = @ptrCast(@alignCast(ctx));
    return .{
        .size = math.rel(frameInfo, calcSize(self)),
        .frame_info = frameInfo,
        .allocator = self.allocator,
        .ptr = try State.init(self.allocator, self.options),
        .ptrEqual = stateEqual,
        .ptrFree = stateFree,
    };
}

fn frame(ctx: *anyopaque, _: *Scene) anyerror!void {
    const self: *NodeArc = @ptrCast(@alignCast(ctx));
    _ = self;
}

fn deinit(ctx: *anyopaque) void {
    const self: *NodeArc = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}

fn format(ctx: *anyopaque, _: ?Allocator) anyerror!std.ArrayList(u8) {
    const self: *NodeArc = @ptrCast(@alignCast(ctx));

    var output = std.ArrayList(u8).init(self.allocator);
    errdefer output.deinit();

    try output.writer().print("{{ .radius = {}, .color = {} }}", .{ self.options.radius, self.options.color });
    return output;
}
