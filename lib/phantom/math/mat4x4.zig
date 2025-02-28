const math = @import("../math.zig");
const Mat4x4 = math.Mat4x4;
const Vec4 = math.Vec4;

pub fn identity(comptime T: type) Mat4x4(T) {
    var self = Mat4x4(T).zero;
    self.value[0] = 1.0;
    self.value[5] = 1.0;
    self.value[10] = 1.0;
    self.value[15] = 1.0;
    return self;
}

pub fn viewport(comptime T: type, width: T, height: T) Mat4x4(T) {
    var self = Mat4x4(T).zero;
    self.value[0] = width / 2;
    self.value[3] = width / 2;
    self.value[5] = -height / 2;
    self.value[7] = height / 2;
    return self;
}

pub fn perspective(comptime T: type, fov: T, aspect: T, near: T, far: T) Mat4x4(T) {
    const f: T = 1 / @tan(fov / 2);

    var self = Mat4x4(T).zero;
    self.value[0] = f / aspect;
    self.value[5] = f;
    self.value[10] = (far + near) / (near - far);
    self.value[11] = (2 * far * near) / (near - far);
    self.value[14] = -1;
    return self;
}

pub fn translate(comptime T: type, x: T, y: T, z: T) Mat4x4(T) {
    var self = identity(T);
    self.value[3] = x;
    self.value[7] = y;
    self.value[11] = z;
    return self;
}

pub fn rotateX(comptime T: type, angle: T) Mat4x4(T) {
    var self = identity(T);
    self.value[5] = @cos(angle);
    self.value[6] = -@sin(angle);
    self.value[9] = @sin(angle);
    self.value[10] = @cos(angle);
    return self;
}

pub fn rotateY(comptime T: type, angle: T) Mat4x4(T) {
    var self = identity(T);
    self.value[0] = @cos(angle);
    self.value[2] = @sin(angle);
    self.value[8] = -@sin(angle);
    self.value[10] = @cos(angle);
    return self;
}

pub fn multVec(comptime T: type, mat: Mat4x4(T), vec: Vec4(T)) Vec4(T) {
    var self = Vec4(T).zero;
    self.value[0] = (mat.value[0] * vec.value[0]) + (mat.value[1] * vec.value[1]) + (mat.value[2] * vec.value[2]) + (mat.value[3] * vec.value[3]);
    self.value[1] = (mat.value[4] * vec.value[0]) + (mat.value[5] * vec.value[1]) + (mat.value[6] * vec.value[2]) + (mat.value[7] * vec.value[3]);
    self.value[2] = (mat.value[8] * vec.value[0]) + (mat.value[9] * vec.value[1]) + (mat.value[10] * vec.value[2]) + (mat.value[11] * vec.value[3]);
    self.value[3] = (mat.value[12] * vec.value[0]) + (mat.value[13] * vec.value[1]) + (mat.value[14] * vec.value[2]) + (mat.value[15] * vec.value[3]);
    return self;
}

pub fn mult(comptime T: type, a: Mat4x4(T), b: Mat4x4(T)) Mat4x4(T) {
    var self = Mat4x4(T).zero;
    for (0..4) |row| {
        for (0..4) |col| {
            var sum: T = 0;
            for (0..4) |k| {
                const a_index = row * 4 + k;
                const b_index = k * 4 + col;

                sum += a.value[a_index] * b.value[b_index];
            }
            self.value[row * 4 + col] = sum;
        }
    }
    return self;
}

pub fn computeBarycentric(comptime T: type, p0: math.Vec2(T), p1: math.Vec2(T), p2: math.Vec2(T), px: T, py: T) math.Vec3(T) {
    const denom = (p1.value[1] - p2.value[1]) * (p0.value[0] - p2.value[0]) +
        (p2.value[0] - p1.value[0]) * (p0.value[1] - p2.value[1]);
    const w0 = ((p1.value[1] - p2.value[1]) * (px - p2.value[0]) + (p2.value[0] - p1.value[0]) * (py - p2.value[1])) / denom;
    const w1 = ((p2.value[1] - p0.value[1]) * (px - p2.value[0]) + (p0.value[0] - p2.value[0]) * (py - p2.value[1])) / denom;
    const w2 = 1.0 - w0 - w1;
    return math.Vec3(T).init(w0, w1, w2);
}
