const std = @import("std");
const Allocator = std.mem.Allocator;
const anyplus = @import("any+");
const vizops = @import("vizops");
const math = @import("../../math.zig");
const Scene = @import("../base.zig");
const Node = @import("../node.zig");
const Fb = @import("../../painting/fb/base.zig");

pub const Options = struct {
    source: *Fb,
    scale: vizops.vector.Float32Vector2 = .{ .value = @splat(1.0) },
    offset: vizops.vector.UsizeVector2 = .{},
    blend: vizops.color.BlendMode = .normal,
    size: ?vizops.vector.Float32Vector2 = null,
};

pub fn NodeFb(comptime Impl: type) type {
    return struct {
        const Self = @This();
        const ImplState = if (@hasDecl(Impl, "State")) Impl.State else void;
        const ImplScene = Impl.Scene;

        const State = struct {
            source: *Fb,
            scale: vizops.vector.Float32Vector2,
            offset: vizops.vector.UsizeVector2,
            blend: vizops.color.BlendMode,
            size: ?vizops.vector.Float32Vector2 = null,
            implState: ImplState,

            pub fn init(alloc: Allocator, options: Options) Allocator.Error!*State {
                const self = try alloc.create(State);
                self.* = .{
                    .source = options.source,
                    .scale = options.scale,
                    .offset = options.offset,
                    .blend = options.blend,
                    .size = options.size,
                    .implState = if (ImplState != void) ImplState.init(alloc, options) else {},
                };
                return self;
            }

            pub fn equal(self: *State, other: *State) bool {
                return std.simd.countTrues(@Vector(6, bool){
                    self.scale.eq(other.scale),
                    self.offset.eq(other.offset),
                    self.blend == other.blend,
                    if (self.size != null and other.size != null) self.size.?.eq(other.size.?) else false,
                    @as(usize, @intFromPtr(self.source)) == @as(usize, @intFromPtr(other.source)) or (self.source.addr() catch null == other.source.addr() catch null),
                    if (ImplState != void) self.implState.equal(other.implState) else true,
                }) == 6;
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

        fn calcSize(self: Self, frameInfo: Node.FrameInfo) vizops.vector.UsizeVector2 {
            const base = if (self.options.size) |size| math.rel(frameInfo, size) else self.options.source.info().res;
            const scaled = base.cast(f32).mul(self.options.scale).cast(usize);
            return if (self.options.size == null) scaled.sub(self.options.offset) else scaled;
        }

        fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!Node.State {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return .{
                .size = self.calcSize(frameInfo),
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
                .size = self.calcSize(frameInfo),
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

            self.options.source.deinit();
            self.node.allocator.destroy(self);
        }

        fn format(ctx: *anyopaque, _: ?Allocator) anyerror!std.ArrayList(u8) {
            const self: *Self = @ptrCast(@alignCast(ctx));

            var output = std.ArrayList(u8).init(self.node.allocator);
            errdefer output.deinit();

            try output.writer().print("{{ .scale = {}, .source = {} }}", .{ self.options.scale, self.options.source });
            return output;
        }

        fn setProperties(ctx: *anyopaque, args: std.StringHashMap(anyplus.Anytype)) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(ctx));

            var iter = args.iterator();
            while (iter.next()) |entry| {
                const key = entry.key_ptr.*;

                if (std.mem.eql(u8, key, "scale")) {
                    self.options.scale = try entry.value_ptr.cast(vizops.vector.Float32Vector2);
                } else if (std.mem.eql(u8, key, "source")) {
                    self.options.source.deinit();
                    self.options.source = try (try entry.value_ptr.cast(*Fb)).dupe();
                } else return error.InvalidKey;
            }
        }
    };
}
