const std = @import("std");
const Vec4 = @import("../math.zig").Vec4;

pub fn cross(comptime T: type, a: Vec4(T), b: Vec4(T)) Vec4(T) {
    return Vec4(T).init(
        a.value[1] * b.value[2] - a.value[2] * b.value[1],
        a.value[2] * b.value[0] - a.value[0] * b.value[2],
        a.value[0] * b.value[1] - a.value[1] * b.value[0],
        0,
    );
}

pub fn length(comptime T: type, v: Vec4(T)) T {
    return std.math.sqrt(v.value[0] * v.value[0] + v.value[1] * v.value[1] + v.value[2] * v.value[2]);
}

pub fn normalize(comptime T: type, v: Vec4(T)) Vec4(T) {
    const len = length(T, v);
    if (len == 0) return v;
    return Vec4(T).init(
        v.value[0] / len,
        v.value[1] / len,
        v.value[2] / len,
        0,
    );
}
