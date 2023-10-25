const std = @import("std");
const vizops = @import("vizops");
const Vector = vizops.Vector(2, usize);

pub const Options = struct {
    element: type = u8,
    size: ?Vector = null,
    depth: ?usize = null,
    @"volatile": bool = false,

    pub fn arrayType(comptime options: Options) type {
        var t: type = [*]options.element;
        if (options.size) |size| {
            const depth = (if (options.depth) |depth| depth else @typeInfo(options.element).Int.bits) / 8;
            const asize = size.value[0] * size.value[1] * depth;

            t = *[asize]options.element;
        }

        if (options.@"volatile") {
            var info = @typeInfo(t).Pointer;
            info.is_volatile = true;
            t = @Type(.{
                .Pointer = info,
            });
        }
        return t;
    }
};

pub fn Base(comptime options: Options) type {
    return struct {
        const Self = @This();

        pub const ArrayType = options.arrayType();

        pub const VTable = struct {
            data: *const fn (*anyopaque) ArrayType,
            size: *const fn (*anyopaque) Vector,
            depth: *const fn (*anyopaque) usize,
        };

        ptr: *anyopaque,
        vtable: *const VTable,

        pub inline fn data(self: Self) ArrayType {
            return self.vtable.data(self.ptr);
        }

        pub inline fn size(self: Self) Vector {
            return options.size orelse self.vtable.size(self.ptr);
        }

        pub inline fn depth(self: Self) usize {
            return options.depth or self.vtable.depth(self.ptr);
        }
    };
}
