const vizops = @import("vizops");
const Vector = vizops.vector.Vector2(usize);
const Color = vizops.vector.Float32Vector4;

const paint = @import("../paint.zig");

pub fn FrameBufferCanvas(comptime FrameBuffer: type, comptime Canvas: type) type {
    return struct {
        const Self = @This();

        fb: FrameBuffer,

        pub fn canvas(self: *Self) Canvas {
            return .{
                .ptr = self,
                .vtable = &.{
                    .size = size,
                    .depth = depth,
                    .draw = draw,
                    .composite = composite,
                },
            };
        }

        fn size(ctx: *anyopaque) Vector {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return self.fb.size();
        }

        fn depth(ctx: *anyopaque) usize {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return self.fb.depth();
        }

        fn draw(ctx: *anyopaque, op: paint.Operation) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            _ = self;
            _ = op;
        }

        fn composite(ctx: *anyopaque, pos: Vector, mode: paint.CompositeMode, image: anytype) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            _ = self;
            _ = pos;
            _ = mode;
            _ = image;
        }
    };
}
