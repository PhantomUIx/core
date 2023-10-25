const std = @import("std");
const Allocator = std.mem.Allocator;

const vizops = @import("vizops");
const Vector = vizops.Vector(2, usize);

const base = @import("base.zig");

pub fn Allocated(comptime options: base.Options) type {
    return struct {
        const Self = @This();

        pub const Base = base.Base(options);

        allocator: Allocator,
        buffer: []options.element,
        size: Vector = options.size orelse undefined,
        depth: usize = options.depth orelse undefined,

        pub usingnamespace if (options.size) |size|
            if (options.depth) |depth|
                struct {
                    pub fn init(alloc: Allocator) Allocator.Error!Self {
                        return .{
                            .allocator = alloc,
                            .buffer = try alloc.alloc(options.element, size.value[0] * size.value[1] * depth),
                        };
                    }
                }
            else
                struct {
                    pub fn init(alloc: Allocator, depth: usize) Allocator.Error!Self {
                        return .{
                            .allocator = alloc,
                            .buffer = try alloc.alloc(options.element, size.value[0] * size.value[1] * depth),
                            .depth = depth,
                        };
                    }
                }
        else
            struct {
                pub fn init(alloc: Allocator, size: Vector, depth: usize) Allocator.Error!Self {
                    return .{
                        .allocator = alloc,
                        .buffer = try alloc.alloc(options.element, size.value[0] * size.value[1] * depth),
                        .size = size,
                        .depth = depth,
                    };
                }
            };

        pub fn deinit(self: Self) void {
            self.allocator.free(self.buffer);
        }

        pub fn framebuffer(self: *Self) Base {
            return .{
                .ptr = self,
                .vtable = &.{
                    .data = impl_data,
                    .size = impl_size,
                    .depth = impl_depth,
                },
            };
        }

        fn impl_data(ctx: *anyopaque) options.arrayType() {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return if (options.size) |size| blk: {
                const depth = (if (options.depth) |depth| depth else @typeInfo(options.element).Int.bits) / 8;
                const asize = size.value[0] * size.value[1] * depth;
                break :blk self.buffer[0..asize];
            } else self.buffer;
        }

        fn impl_size(ctx: *anyopaque) Vector {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return self.size;
        }

        fn impl_depth(ctx: *anyopaque) usize {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return self.depth;
        }
    };
}
