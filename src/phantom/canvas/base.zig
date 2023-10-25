const paint = @import("../paint.zig");

const vizops = @import("vizops");
const Vector = vizops.vector.Vector2(usize);
const Color = vizops.vector.Float32Vector4;

pub const Options = struct {
    size: ?Vector = null,
    depth: ?usize = null,
};

pub const VTable = struct {
    size: *const fn (*anyopaque) Vector,
    depth: *const fn (*anyopaque) u8,
    draw: *const fn (*anyopaque, paint.Operation) anyerror!void,
    composite: *const fn (*anyopaque, Vector, paint.CompositeMode, anytype) anyerror!void,
};

pub fn Base(comptime options: Options) type {
    return struct {
        const Self = @This();

        ptr: *anyopaque,
        vtable: *const VTable,

        pub inline fn size(self: Self) Vector {
            return options.size or self.vtable.size(self.ptr);
        }

        pub inline fn depth(self: Self) u8 {
            return options.depth or self.vtable.depth(self.ptr);
        }

        pub inline fn draw(self: Self, op: paint.Operation) anyerror!void {
            return self.vtable.draw(self.ptr, op);
        }

        pub inline fn composite(self: Self, pos: Vector, mode: paint.CompositeMode, image: anytype) anyerror!void {
            return self.vtable.composite(self.ptr, pos, mode, image);
        }
    };
}
