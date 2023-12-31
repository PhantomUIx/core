const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const math = @import("../../math.zig");
const Scene = @import("../base.zig");
const Node = @import("../node.zig");

pub const Options = struct {
    radius: f32,
    angles: vizops.vector.Float32Vector2,
    color: vizops.color.Any,
};

pub fn NodeArc(comptime Impl: type) type {
    return struct {
        const Self = @This();
        const ImplState = if (@hasDecl(Impl, "State")) Impl.State else void;
        const ImplScene = Impl.Scene;

        const State = struct {
            color: vizops.color.Any,
            implState: ImplState,

            pub fn init(alloc: Allocator, options: Options) Allocator.Error!*State {
                const self = try alloc.create(State);
                self.* = .{
                    .color = options.color,
                    .implState = if (ImplState != void) ImplState.init(alloc, options) else {},
                };
                return self;
            }

            pub fn equal(self: *State, other: *State) bool {
                return std.simd.countTrues(@Vector(2, bool){
                    self.color.equal(other.color),
                    if (ImplState != void) self.implState.equal(other.implState) else true,
                }) == 2;
            }

            pub fn deinit(self: *State, alloc: Allocator) void {
                if (ImplState != void) self.implState.deinit(alloc);
                alloc.destroy(self);
            }
        };

        options: Options,
        node: Node,
        impl: Impl,

        pub fn new(alloc: Allocator, id: ?usize, options: Options) Allocator.Error!*Node {
            const self = try alloc.create(Self);
            self.* = .{
                .options = options,
                .node = .{
                    .allocator = alloc,
                    .ptr = self,
                    .type = @typeName(Self),
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
                .impl = undefined,
            };

            if (@hasDecl(Impl, "new")) {
                try Impl.init(self);
            }
            return &self.node;
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

        fn calcSize(self: *Self) vizops.vector.Float32Vector2 {
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
            const self: *Self = @ptrCast(@alignCast(ctx));
            return try new(self.node.allocator, @returnAddress(), self.options);
        }

        fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!Node.State {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return .{
                .size = math.rel(frameInfo, calcSize(self)),
                .frame_info = frameInfo,
                .allocator = self.node.allocator,
                .ptr = try State.init(self.node.allocator, self.options),
                .ptrEqual = stateEqual,
                .ptrFree = stateFree,
                .type = @typeName(Self),
            };
        }

        fn preFrame(ctx: *anyopaque, frameInfo: Node.FrameInfo, baseScene: *Scene) anyerror!Node.State {
            const self: *Self = @ptrCast(@alignCast(ctx));

            if (@hasDecl(Impl, "preFrame")) {
                try Impl.preFrame(self, frameInfo, @ptrCast(@alignCast(baseScene.ptr)));
            }

            return .{
                .size = math.rel(frameInfo, calcSize(self)),
                .frame_info = frameInfo,
                .allocator = self.node.allocator,
                .ptr = try State.init(self.node.allocator, self.options),
                .ptrEqual = stateEqual,
                .ptrFree = stateFree,
                .type = @typeName(Self),
            };
        }

        fn frame(ctx: *anyopaque, baseScene: *Scene) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(ctx));

            if (@hasDecl(Impl, "frame")) {
                try Impl.frame(self, @ptrCast(@alignCast(baseScene.ptr)));
            }
        }

        fn deinit(ctx: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ctx));

            if (@hasDecl(Impl, "deinit")) {
                Impl.deinit(self);
            }

            self.node.allocator.destroy(self);
        }

        fn format(ctx: *anyopaque, _: ?Allocator) anyerror!std.ArrayList(u8) {
            const self: *Self = @ptrCast(@alignCast(ctx));

            var output = std.ArrayList(u8).init(self.node.allocator);
            errdefer output.deinit();

            try output.writer().print("{{ .radius = {}, .color = {} }}", .{ self.options.radius, self.options.color });
            return output;
        }
    };
}
