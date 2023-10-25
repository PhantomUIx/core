const vizops = @import("vizops");
const Vector = vizops.vector.Vector2(usize);
const Color = vizops.vector.Float32Vector4;

pub const Options = struct {
    size: ?Vector = null,
    depth: ?usize = null,
};

pub const FillMode = union(enum) {
    fill: void,
    border: usize,
};

pub const CompositeMode = enum {
    source,
    xor,
    add,
    multiply,
};

pub const Operation = union(enum) {
    rect: struct {
        fill: FillMode,
        pos: Vector,
        size: Vector,
        color: Color,
    },
    circle: struct {
        fill: FillMode,
        pos: Vector,
        rad: f32,
    },
    line: struct {
        depth: usize,
        start: Vector,
        end: Vector,
        color: Color,
    },
    clear: struct {
        color: Color,
    },
};

pub const VTable = struct {
    size: *const fn (*anyopaque) Vector,
    depth: *const fn (*anyopaque) u8,
    draw: *const fn (*anyopaque, Operation) anyerror!void,
    composite: *const fn (*anyopaque, Vector, CompositeMode, anytype) anyerror!void,
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

        pub inline fn draw(self: Self, op: Operation) anyerror!void {
            return self.vtable.draw(self.ptr, op);
        }

        pub inline fn composite(self: Self, pos: Vector, mode: CompositeMode, image: anytype) anyerror!void {
            return self.vtable.composite(self.ptr, pos, mode, image);
        }
    };
}
