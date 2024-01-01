const std = @import("std");
const Allocator = std.mem.Allocator;
const anyplus = @import("any+");
const vizops = @import("vizops");
const math = @import("../../math.zig");
const painting = @import("../../painting.zig");
const Node = @import("../node.zig");
const Scene = @import("../base.zig");

pub const Options = struct {
    radius: ?painting.Radius = null,
    size: vizops.vector.Float32Vector2,
    color: vizops.color.Any,
};

pub fn NodeRect(comptime Impl: type) type {
    return struct {
        const Self = @This();
        const ImplState = if (@hasDecl(Impl, "State")) Impl.State else void;
        const ImplScene = Impl.Scene;

        pub const State = struct {
            radius: ?painting.Radius,
            color: vizops.color.Any,
            implState: ImplState,

            pub fn init(alloc: Allocator, options: Options) Allocator.Error!*State {
                const self = try alloc.create(State);
                self.* = .{
                    .radius = options.radius,
                    .color = options.color,
                    .implState = if (ImplState != void) ImplState.init(alloc, options) else {},
                };
                return self;
            }

            pub fn equal(self: *State, other: *State) bool {
                return std.simd.countTrues(@Vector(3, bool){
                    if (self.radius) |srd| if (other.radius) |ord| srd.equal(ord) else false else if (other.radius) |_| false else true,
                    self.color.equal(other.color),
                    if (ImplState != void) self.implState.equal(other.implState) else true,
                }) == 3;
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
            errdefer alloc.destroy(self);

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
                        .setProperties = setProperties,
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

        fn dupe(ctx: *anyopaque) anyerror!*Node {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return try new(self.node.allocator, @returnAddress(), self.options);
        }

        fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!Node.State {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return .{
                .size = math.rel(frameInfo, self.options.size),
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
                try Impl.preFrame(self, frameInfo, @ptrCast(@alignCast(baseScene.ptr)), baseScene.subscene);
            }

            return .{
                .size = math.rel(frameInfo, self.options.size),
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
                try Impl.frame(self, @ptrCast(@alignCast(baseScene.ptr)), baseScene.subscene);
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

            try output.writer().print("{{ .size = {}, .color = {}", .{ self.options.size, self.options.color });

            if (self.options.radius) |r| {
                try output.writer().print(", .radius = {}", .{r});
            }

            try output.writer().writeAll(" }");
            return output;
        }

        fn setProperties(ctx: *anyopaque, args: std.StringHashMap(anyplus.Anytype)) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(ctx));

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
    };
}
