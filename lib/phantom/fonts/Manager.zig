const std = @import("std");
const Allocator = std.mem.Allocator;
const Font = @import("Font.zig");
const Loader = @import("Loader.zig");
const math = @import("../math.zig");
const Self = @This();

allocator: Allocator,
loaders: std.ArrayListUnmanaged(*Loader),
dirs: std.ArrayListUnmanaged(std.fs.Dir),

pub fn create(alloc: Allocator) Allocator.Error!*Self {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .loaders = .{},
        .dirs = .{},
    };
    return self;
}

pub fn lookupFont(self: *Self, name: []const u8, size: math.Vec2(usize)) !*Font {
    for (self.dirs.items) |dir| {
        for (self.loaders.items) |loader| {
            return loader.lookupFontDir(dir, name, size) catch |err| switch (err) {
                error.NoEntry => continue,
                else => |e| return e,
            };
        }
    }
    return error.NoEntry;
}

pub fn destroy(self: *Self) void {
    for (self.loaders.items) |loader| loader.destroy();
    self.loaders.deinit(self.allocator);

    for (self.dirs.items) |*dir| dir.close();
    self.dirs.deinit(self.allocator);

    self.allocator.destroy(self);
}

test "Expect fail" {
    const mngr = try create(std.testing.allocator);
    defer mngr.destroy();

    try std.testing.expectError(error.NoEntry, mngr.lookupFont("AAAA", math.Vec2(usize).zero));
}
