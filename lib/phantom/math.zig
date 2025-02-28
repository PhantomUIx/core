//! Math graphics types

const std = @import("std");
const expectEqual = std.testing.expectEqual;

/// Base vector implementation
pub fn Vec(comptime Size: comptime_int, comptime T: type, comptime FactoryFunc: fn (comptime Self: type) type) type {
    return struct {
        const Self = @This();

        value: Value,

        pub const Value = @Vector(Size, T);
        pub const init = FactoryFunc(Self).init;

        pub inline fn addValue(self: Self, other: Value) Self {
            return .{ .value = self.value + other };
        }

        pub inline fn add(self: Self, other: Self) Self {
            return self.addValue(other.value);
        }

        pub inline fn subValue(self: Self, other: Value) Self {
            return .{ .value = self.value - other };
        }

        pub inline fn sub(self: Self, other: Self) Self {
            return self.subValue(other.value);
        }

        pub inline fn mulValue(self: Self, other: Value) Self {
            return .{ .value = self.value * other };
        }

        pub inline fn mul(self: Self, other: Self) Self {
            return self.mulValue(other.value);
        }

        pub inline fn divValue(self: Self, other: Value) Self {
            return .{ .value = self.value / other };
        }

        pub inline fn div(self: Self, other: Self) Self {
            return self.divValue(other.value);
        }

        pub const zero: Self = .{
            .value = [_]T{0} ** Size,
        };

        test {
            _ = FactoryFunc(Self);
        }
    };
}

/// Vector with 2 elements
pub fn Vec2(comptime T: type) type {
    return Vec(2, T, (struct {
        fn FactoryFunc(comptime Self: type) type {
            return struct {
                pub fn init(x: T, y: T) Self {
                    return .{ .value = .{ x, y } };
                }

                test {
                    const vec = init(1, 2);
                    try expectEqual(Self.Value{ 2, 4 }, vec.add(vec).value);
                    try expectEqual(Self.zero.value, vec.sub(vec).value);
                }
            };
        }
    }).FactoryFunc);
}

/// Vector with 3 elements
pub fn Vec3(comptime T: type) type {
    return Vec(3, T, (struct {
        fn FactoryFunc(comptime Self: type) type {
            return struct {
                pub fn init(x: T, y: T, z: T) Self {
                    return .{ .value = .{ x, y, z } };
                }

                test {
                    const vec = init(1, 2, 3);
                    try expectEqual(Self.Value{ 2, 4, 6 }, vec.add(vec).value);
                    try expectEqual(Self.zero.value, vec.sub(vec).value);
                }
            };
        }
    }).FactoryFunc);
}

/// Vector with 4 elements
pub fn Vec4(comptime T: type) type {
    return Vec(4, T, (struct {
        fn FactoryFunc(comptime Self: type) type {
            return struct {
                pub fn init(x: T, y: T, z: T, w: T) Self {
                    return .{ .value = .{ x, y, z, w } };
                }

                test {
                    const vec = init(1, 2, 3, 4);
                    try expectEqual(Self.Value{ 2, 4, 6, 8 }, vec.add(vec).value);
                    try expectEqual(Self.zero.value, vec.sub(vec).value);
                }
            };
        }
    }).FactoryFunc);
}

/// Base matrix implementation
pub fn Mat(comptime MatSize: comptime_int, comptime VecSize: comptime_int, comptime T: type, comptime FactoryFunc: fn (comptime Self: type) type) type {
    return Vec(MatSize * VecSize, T, FactoryFunc);
}

/// 3x3 matrix
pub fn Mat3x3(comptime T: type) type {
    return Mat(3, 3, T, (struct {
        fn FactoryFunc(comptime Self: type) type {
            return struct {
                pub fn init(
                    x0: T,
                    y0: T,
                    z0: T,
                    x1: T,
                    y1: T,
                    z1: T,
                    x2: T,
                    y2: T,
                    z2: T,
                ) Self {
                    return .{ .value = .{
                        x0,
                        y0,
                        z0,
                        x1,
                        y1,
                        z1,
                        x2,
                        y2,
                        z2,
                    } };
                }
            };
        }
    }).FactoryFunc);
}

/// 4x4 matrix
pub fn Mat4x4(comptime T: type) type {
    return Mat(4, 4, T, (struct {
        fn FactoryFunc(comptime Self: type) type {
            return struct {
                pub fn init(
                    x0: T,
                    y0: T,
                    z0: T,
                    w0: T,
                    x1: T,
                    y1: T,
                    z1: T,
                    w1: T,
                    x2: T,
                    y2: T,
                    z2: T,
                    w2: T,
                    x3: T,
                    y3: T,
                    z3: T,
                    w3: T,
                ) Self {
                    return .{ .value = .{
                        x0,
                        y0,
                        z0,
                        w0,
                        x1,
                        y1,
                        z1,
                        w1,
                        x2,
                        y2,
                        z2,
                        w2,
                        x3,
                        y3,
                        z3,
                        w3,
                    } };
                }
            };
        }
    }).FactoryFunc);
}

/// A rectangle
pub fn Rect(comptime T: type) type {
    return struct {
        const Self = @This();
        const Value = Vec2(T);

        position: Value,
        size: Value,

        pub inline fn init(pos: Value.Value, size: Value.Value) Self {
            return .{
                .position = .{ .value = pos },
                .size = .{ .value = size },
            };
        }

        /// Gets the point at the absolute center.
        pub inline fn center(self: Self) Value {
            return self.position.add(self.size.divValue(.{ 2, 2 }));
        }

        /// Gets the point at the top left.
        pub inline fn topLeft(self: Self) Value {
            return self.position;
        }

        /// Gets the point at the top right.
        pub inline fn topRight(self: Self) Value {
            return self.position.addValue(.{ self.size.value[0], 0 });
        }

        /// Gets the point at the bottom left.
        pub inline fn bottomLeft(self: Self) Value {
            return self.position.addValue(.{ 0, self.size.value[1] });
        }

        /// Gets the point at the bottom right.
        pub inline fn bottomRight(self: Self) Value {
            return self.position.add(self.size);
        }

        test {
            const rect = init(.{ 100, 100 }, .{ 100, 100 });

            try expectEqual(Value.Value{ 150, 150 }, rect.center().value);

            try expectEqual(Value.Value{ 100, 100 }, rect.topLeft().value);
            try expectEqual(Value.Value{ 200, 100 }, rect.topRight().value);

            try expectEqual(Value.Value{ 100, 200 }, rect.bottomLeft().value);
            try expectEqual(Value.Value{ 200, 200 }, rect.bottomRight().value);
        }
    };
}

pub const mat4x4 = @import("math/mat4x4.zig");
pub const vec4 = @import("math/vec4.zig");

test {
    inline for (&.{ usize, isize, f32, f64, f128 }) |T| {
        _ = Rect(T);
        _ = Vec2(T);
        _ = Vec3(T);
        _ = Vec4(T);
        _ = Mat3x3(T);
        _ = Mat4x4(T);
    }

    _ = mat4x4;
    _ = vec4;
}
