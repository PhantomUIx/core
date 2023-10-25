const std = @import("std");
const Allocator = std.mem.Allocator;

const vizops = @import("vizops");
const Vector = vizops.vector.Vector2(usize);
const Color = vizops.vector.Float32Vector4;

const paint = @import("../paint.zig");

const base = @import("base.zig");
const Base = base.Base;

const Damaged = @This();

pub const Region = struct {
    pos: Vector,
    size: Vector,
};

pub const RegionList = std.ArrayList(Region);

ptr: *anyopaque,
list: RegionList,
vtable: *const base.VTable,

pub fn init(ptr: *anyopaque, vtable: *const Base.VTable, alloc: Allocator) Damaged {
    return .{
        .ptr = ptr,
        .list = RegionList.init(alloc),
        .vtable = vtable,
    };
}

pub fn deinit(self: *Damaged) void {
    self.list.deinit();
}

pub fn canvas(self: *Damaged, comptime options: base.Options) Base(options) {
    return .{
        .ptr = self,
        .vtable = &.{
            .size = size,
            .depth = depth,
            .draw = draw,
            .composite = composite,
        },
    };
}

fn size(ctx: *anyopaque) Vector {
    const self: *Base = @ptrCast(@alignCast(ctx));
    return self.vtable.size(self.ptr);
}

fn depth(ctx: *anyopaque) u8 {
    const self: *Base = @ptrCast(@alignCast(ctx));
    return self.vtable.depth(self.ptr);
}

fn damage(self: *Damaged, op: paint.Operation) ?Region {
    return switch (op) {
        .rect => |r| .{
            .pos = r.pos,
            .size = r.size,
        },
        .circle => |c| .{
            .pos = c.pos,
            .size = c.rad * 2,
        },
        .clear => .{
            .pos = Vector.zero(),
            .size = self.size(),
        },
        else => null,
    };
}

fn draw(ctx: *anyopaque, op: paint.Operation) anyerror!void {
    const self: *Damaged = @ptrCast(@alignCast(ctx));
    if (self.damage(op)) |region| try self.list.append(region);
    return self.vtable.draw(self.ptr, op);
}

fn composite(ctx: *anyopaque, pos: Vector, mode: paint.CompositeMode, image: anytype) anyerror!void {
    const self: *Damaged = @ptrCast(@alignCast(ctx));

    try self.list.append(.{
        .pos = pos,
        .size = image.size(),
    });

    return self.vtable.composite(self.ptr, pos, mode, image);
}
