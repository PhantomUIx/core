const vizops = @import("vizops");
const Vector = vizops.vector.Vector2(usize);
const Color = vizops.vector.Float32Vector4;

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
