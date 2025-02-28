const std = @import("std");
const Font = @import("Font.zig");
const math = @import("../math.zig");
const Self = @This();

pub const VTable = struct {
    load: *const fn (*anyopaque, reader: std.io.AnyReader, data_size: ?usize) anyerror!*Font,
    destroy: *const fn (*anyopaque) void,
};

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn load(self: *Self, reader: std.io.AnyReader, data_size: ?usize) anyerror!*Font {
    return self.vtable.load(self.ptr, reader, data_size);
}

pub fn loadFile(self: *Self, file: std.fs.File) anyerror!*Font {
    var metadata = try file.metadata();
    return self.load(file.reader().any(), metadata.size());
}

pub fn lookupFont(self: *Self, sources: std.StringArrayHashMap(struct { std.io.AnyReader, ?usize }), name: []const u8, size: math.Vec2(usize)) anyerror!*Font {
    var iter = sources.iterator();
    while (iter.next()) |entry| {
        const font = self.load(entry.value_ptr[0], entry.value_ptr[1]) catch continue;
        const label = font.getLabel() orelse entry.key_ptr;

        if (std.mem.eql(u8, label, name) and std.meta.eql(font.getSize().value, size.value)) {
            return font;
        }

        font.deinit();
    }
    return error.NotFound;
}

pub fn lookupFontDir(self: *Self, dir: std.fs.Dir, name: []const u8, size: math.Vec2(usize)) anyerror!*Font {
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file or entry.kind != .sym_link) continue;

        var file = try dir.openFile(entry.name, .{});
        defer file.close();

        const font = self.loadFile(file) catch continue;
        const label = font.getLabel() orelse std.fs.path.stem(entry.name);

        if (std.mem.eql(u8, label, name) and std.meta.eql(font.getSize().value, size.value)) {
            return font;
        }

        font.deinit();
    }
    return error.NotFound;
}

pub inline fn destroy(self: *Self) void {
    return self.vtable.destroy(self.ptr);
}
