const std = @import("std");
const vizops = @import("vizops");
const Vector = vizops.Vector(2, usize);

pub fn BaseRuntimeSized(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const VTable = struct {
            data: *const fn (*anyopaque) [*]T,
            size: *const fn (*anyopaque) Vector,
            depth: *const fn (*anyopaque) usize,
        };

        ptr: *anyopaque,
        vtable: *const VTable,

        pub inline fn data(self: Self) [*]T {
            return self.vtable.data(self.ptr);
        }

        pub inline fn size(self: Self) Vector {
            return self.vtable.size(self.ptr);
        }

        pub inline fn depth(self: Self) usize {
            return self.vtable.depth(self.ptr);
        }
    };
}

pub fn BaseComptimeSized(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const VTable = struct {
            data: *const fn (*anyopaque) [*]T,
            size: *const fn (*anyopaque) Vector,
        };

        ptr: *anyopaque,
        vtable: *const VTable,

        pub inline fn data(self: Self) [*]T {
            return self.vtable.data(self.ptr);
        }

        pub inline fn size(self: Self) Vector {
            return self.vtable.size(self.ptr);
        }

        pub inline fn depth(_: Self) usize {
            return std.math.maxInt(T);
        }
    };
}

pub const Base = BaseRuntimeSized(u8);
