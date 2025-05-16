const std = @import("std");
const Allocator = std.mem.Allocator;
const math = @import("../../../math.zig");
const graphics = @import("../../../graphics.zig");
const Context = @import("../../Context.zig");
const Surface = @import("../../Surface.zig");
const z2d = @import("z2d");
const zigimg = @import("zigimg");
const SelfContext = @import("Context.zig");
const Self = @This();

allocator: Allocator,
base: Surface,
surface: z2d.Surface,
context: ?*Context,

const vtable: Surface.VTable = .{
    .getSize = vtable_getSize,
    .getFormat = vtable_getFormat,
    .getBuffer = vtable_getBuffer,
    .getContext = vtable_getContext,
    .snapshot = vtable_snapshot,
    .destroy = vtable_destroy,
};

pub fn create(alloc: Allocator, format: graphics.Format, width: usize, height: usize) !*Surface {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .base = .{
            .ptr = self,
            .vtable = &vtable,
        },
        .surface = try z2d.Surface.init(switch (format) {
            .rgba32 => .image_surface_rgba,
            .rgbx32 => .image_surface_rgb,
            else => return error.InvalidFormat,
        }, alloc, @intCast(width), @intCast(height)),
        .context = null,
    };
    return &self.base;
}

pub fn getSize(self: *const Self) math.Vec2(usize) {
    return math.Vec2(usize).init(
        @intCast(self.surface.getWidth()),
        @intCast(self.surface.getHeight()),
    );
}

pub fn getFormat(self: *const Self) ?graphics.Format {
    return switch (self.surface.getFormat()) {
        .rgba => .rgba32,
        .rgb => .rgbx32,
        else => null,
    };
}

pub fn getBuffer(self: *const Self) ?[]const u8 {
    return switch (self.surface) {
        inline else => |t| @ptrCast(@alignCast(t.buf[0..@intCast(t.width * t.height)])),
    };
}

pub fn getContext(self: *Self, kind: Context.Kind) Context.Error!*Context {
    if (self.context) |ctx| return ctx;
    if (kind != .@"2d") return error.InvalidKind;

    const ctx = try SelfContext.create(self.allocator, &self.surface);
    errdefer ctx.destroy();
    self.context = ctx;
    return ctx;
}

pub fn snapshot(self: *Self) !graphics.Source {
    return .{
        .img = try zigimg.Image.fromRawPixels(
            self.allocator,
            @intCast(self.surface.getWidth()),
            @intCast(self.surface.getHeight()),
            self.getBuffer() orelse unreachable,
            (self.getFormat() orelse return error.InvalidFormat).asZigimg(),
        ),
    };
}

pub fn destroy(self: *Self) void {
    self.surface.deinit(self.allocator);
    self.allocator.destroy(self);
}

fn vtable_getSize(ptr: *anyopaque) math.Vec2(usize) {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.getSize();
}

fn vtable_getFormat(ptr: *anyopaque) ?graphics.Format {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.getFormat();
}

fn vtable_getBuffer(ptr: *anyopaque) ?[]const u8 {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.getBuffer();
}

fn vtable_getContext(ptr: *anyopaque, kind: Context.Kind) Context.Error!*Context {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.getContext(kind);
}

fn vtable_snapshot(ptr: *anyopaque) anyerror!graphics.Source {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.snapshot();
}

fn vtable_destroy(ptr: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.destroy();
}

test {
    const surface = try create(std.testing.allocator, .rgba32, 100, 100);
    defer surface.destroy();

    try std.testing.expect(surface.getBuffer() != null);
    try std.testing.expectEqual(@Vector(2, usize){ 100, 100 }, surface.getSize().value);
    try std.testing.expectEqual(.rgba32, surface.getFormat());

    const ctx = try surface.getContext(.@"2d");
    defer ctx.destroy();

    try ctx.render(.{
        .@"2d" = .{
            .rect = .{
                .source = .{ .color = graphics.Color.init(.{ 1, 0, 0, 1 }) },
                .rect = math.Rect(f32).init(.{ 20, 20 }, .{ 50, 50 }),
                .mode = .fill,
            },
        },
    });

    try ctx.render(.{
        .@"2d" = .{
            .rect = .{
                .source = .{ .color = graphics.Color.init(.{ 0, 1, 0, 1 }) },
                .rect = math.Rect(f32).init(.{ 15, 15 }, .{ 25, 25 }),
                .mode = .{ .stroke = .{ .width = 6.0 } },
            },
        },
    });

    try ctx.render(.{
        .@"2d" = .{
            .rect = .{
                .source = .{ .color = graphics.Color.init(.{ 0, 0, 1, 1 }) },
                .rect = math.Rect(f32).init(.{ 50, 15 }, .{ 25, 25 }),
                .mode = .{ .stroke = .{ .width = 6.0 } },
                .border_radius = graphics.Context.@"2d".Operation.Rect.BorderRadius.all(0.6),
            },
        },
    });

    var snap = try surface.snapshot();
    defer snap.destroy();

    const buffer = try std.testing.allocator.alloc(u8, 1024 * snap.img.imageByteSize());
    defer std.testing.allocator.free(buffer);

    const buffer_hash = std.zig.hashSrc(try snap.img.writeToMemory(buffer, .{ .png = .{} }));

    try std.testing.expectEqualSlices(u8, &[_]u8{
        0xF2, 0x05, 0xB9, 0xDA, 0x1E, 0xF3, 0x5B, 0x37, 0xF7, 0x69, 0x30, 0xFF, 0x13, 0x63, 0xF1, 0x1D,
    }, &buffer_hash);
}
