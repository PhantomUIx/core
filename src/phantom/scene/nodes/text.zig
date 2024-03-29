const std = @import("std");
const Allocator = std.mem.Allocator;
const vizops = @import("vizops");
const fonts = @import("../../fonts.zig");
const Scene = @import("../base.zig");
const Node = @import("../node.zig");

pub const Options = struct {
    font: *fonts.Font,
    view: std.unicode.Utf8View,
};

pub fn NodeText(comptime Impl: type) type {
    return struct {
        const Self = @This();
        const ImplState = if (@hasDecl(Impl, "State")) Impl.State else void;
        const ImplScene = Impl.Scene;

        const State = struct {
            font: *fonts.Font,
            view: std.unicode.Utf8View,
            implState: ImplState,

            pub fn init(alloc: Allocator, options: Options) Allocator.Error!*State {
                const self = try alloc.create(State);
                self.* = .{
                    .font = options.font,
                    .view = options.view,
                    .implState = if (ImplState != void) ImplState.init(alloc, options) else {},
                };
                return self;
            }

            pub fn equal(self: *State, other: *State) bool {
                return std.simd.countTrues(@Vector(3, bool){
                    self.font == other.font,
                    std.mem.eql(u8, self.view.bytes, other.view.bytes),
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

        fn calcSize(self: *Self) !vizops.vector.UsizeVector2 {
            var viewIter = self.options.view.iterator();

            var width: usize = 0;
            var yMaxMin = vizops.vector.UsizeVector2.zero();

            while (viewIter.nextCodepoint()) |cp| {
                const glyph = try self.options.font.lookupGlyph(cp);

                width += @intCast(glyph.advance.value[0]);
                yMaxMin.value[0] = @max(yMaxMin.value[0], @as(usize, @intCast(glyph.bearing.value[1])));

                if (glyph.bearing.value[1] >= glyph.size.value[1]) {
                    yMaxMin.value[1] = @min(yMaxMin.value[1], @as(usize, @intCast(glyph.bearing.value[1] - @as(i8, @intCast(glyph.size.value[1])))));
                } else {
                    yMaxMin.value[1] = @min(yMaxMin.value[1], @as(usize, @intCast(glyph.size.value[1] - glyph.size.value[1])));
                }
            }

            return .{ .value = .{ width, yMaxMin.value[0] - yMaxMin.value[1] } };
        }

        fn dupe(ctx: *anyopaque) anyerror!*Node {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return try new(self.node.allocator, @returnAddress(), self.options);
        }

        fn state(ctx: *anyopaque, frameInfo: Node.FrameInfo) anyerror!Node.State {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return .{
                .size = try calcSize(self),
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
                .size = try calcSize(self),
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

            try output.writer().print("{{ .font = {}, .text = \"{s}\" }}", .{ self.options.font, std.unicode.fmtUtf8(self.options.view.bytes) });
            return output;
        }
    };
}
