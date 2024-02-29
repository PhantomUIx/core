const std = @import("std");
const vizops = @import("vizops");
const math = @import("../../math.zig");
const painting = @import("../../painting.zig");
const BaseScene = @import("../base.zig");

pub const Scene = @import("fb/scene.zig");

pub const NodeArc = @import("../nodes/arc.zig").NodeArc(struct {
    const Self = @This();
    pub const Scene = @import("fb/scene.zig");

    pub fn frame(self: *NodeArc, scene: *Self.Scene, subscene: ?BaseScene.Sub) anyerror!void {
        const size = (try self.node.state(scene.base.frameInfo())).size;
        const pos: vizops.vector.UsizeVector2 = if (subscene) |sub| sub.pos else .{};

        const bufferInfo = scene.buffer.info();
        const buffer = try self.node.allocator.alloc(u8, @divExact(bufferInfo.colorFormat.width(), 8));
        defer self.node.allocator.free(buffer);
        try vizops.color.writeAnyBuffer(bufferInfo.colorFormat, buffer, self.options.color);

        try painting.Canvas.init(scene.buffer, .{
            .size = size,
            .pos = pos,
        }).arc(vizops.vector.UsizeVector2.init([_]usize{ std.math.lossyCast(usize, self.options.radius), 0 }), self.options.angles, self.options.radius, buffer);
    }
});

pub const NodeFrameBuffer = @import("../nodes/fb.zig").NodeFb(struct {
    const Self = @This();
    pub const Scene = @import("fb/scene.zig");

    pub fn frame(self: *NodeFrameBuffer, scene: *Self.Scene, subscene: ?BaseScene.Sub) anyerror!void {
        const size = (try self.node.state(scene.base.frameInfo())).size;
        const pos: vizops.vector.UsizeVector2 = if (subscene) |sub| sub.pos else .{};

        try self.options.source.blt(.to, scene.buffer, .{
            .sourceOffset = self.options.offset,
            .destOffset = pos,
            .size = size,
            .blend = self.options.blend,
        });
    }
});

pub const NodeRect = @import("../nodes/rect.zig").NodeRect(struct {
    const Self = @This();
    pub const Scene = @import("fb/scene.zig");

    pub fn frame(self: *NodeRect, scene: *Self.Scene, subscene: ?BaseScene.Sub) anyerror!void {
        const size = (try self.node.state(scene.base.frameInfo())).size;
        const pos: vizops.vector.UsizeVector2 = if (subscene) |sub| sub.pos else .{};

        const bufferInfo = scene.buffer.info();
        const buffer = try self.node.allocator.alloc(u8, @divExact(bufferInfo.colorFormat.width(), 8));
        defer self.node.allocator.free(buffer);
        try vizops.color.writeAnyBuffer(bufferInfo.colorFormat, buffer, self.options.color);

        const radius = self.options.radius orelse painting.Radius(f32){};

        try painting.Canvas.init(scene.buffer, .{
            .size = size,
            .pos = pos,
        }).rect(vizops.vector.UsizeVector2.zero(), size, radius, buffer);
    }
});

pub const NodeText = @import("../nodes/text.zig").NodeText(struct {
    const Self = @This();
    pub const Scene = @import("fb/scene.zig");

    pub fn frame(self: *NodeText, scene: *Self.Scene, subscene: ?BaseScene.Sub) anyerror!void {
        const startPos: vizops.vector.UsizeVector2 = if (subscene) |sub| sub.pos else .{};

        const view = try std.unicode.Utf8View.init(self.options.text);
        var viewIter = view.iterator();

        var origin = vizops.vector.UsizeVector2.zero();

        while (viewIter.nextCodepoint()) |cp| {
            const glyph = try self.options.font.lookupGlyph(cp);

            try glyph.fb.blt(.to, scene.buffer, .{
                .destOffset = origin.add(startPos).add(.{
                    glyph.bearing.value[0],
                    -glyph.bearing.value[1],
                }),
                .size = glyph.size,
            });

            origin = origin.add(.{
                glyph.advance.value[0],
                -glyph.advance.value[1],
            });
        }
    }
});
