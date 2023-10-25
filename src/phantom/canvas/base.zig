const vizops = @import("vizops");
const Vector = vizops.vector.Vector2(usize);
const Color = vizops.vector.Float32Vector4;

const Base = @This();

pub const FillMode = union(enum) {
    fill: void,
    border: usize,
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
    draw: *const fn (*anyopaque, Operation) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn size(self: Base) Vector {
    return self.vtable.size(self.ptr);
}

pub inline fn depth(self: Base) u8 {
    return self.vtable.depth(self.ptr);
}

pub inline fn draw(self: Base, op: Operation) void {
    return self.vtable.draw(self.ptr, op);
}
