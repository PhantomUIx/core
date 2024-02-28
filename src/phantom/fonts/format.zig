const std = @import("std");
const metap = @import("meta+");
const Font = @import("font.zig");
const Self = @This();

const BaseVTable = struct {
    loadBuffer: *const fn (*anyopaque, []const u8) anyerror!*Font,
    deinit: ?*const fn (*anyopaque) void = null,
};

const FsVTable = struct {
    loadFile: ?*const fn (*anyopaque, std.fs.File) anyerror!*Font = null,
};

pub const VTable = metap.structs.fields.mix(BaseVTable, if (@hasDecl(std.os.system, "fd_t")) FsVTable else struct {});

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn loadBuffer(self: *Self, buff: []const u8) !*Font {
    return self.vtable.loadBuffer(self.ptr, buff);
}

pub inline fn loadFile(self: *Self, file: std.fs.File) !*Font {
    if (@hasDecl(std.os.system, "fd_t")) {
        if (self.vtable.loadFile) |f| return f(self.ptr, file);
        return error.NotImplemented;
    }
    return error.NotSupported;
}

pub inline fn deinit(self: *Self) void {
    return if (self.vtable.deinit) |f| f(self.ptr) else {};
}
