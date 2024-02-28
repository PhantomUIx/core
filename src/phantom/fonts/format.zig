const std = @import("std");
const metap = @import("meta+");
const Font = @import("font.zig");
const vizops = @import("vizops");
const Self = @This();

pub const LoadOptions = struct {
    foregroundColor: vizops.color.Any,
    backgroundColor: vizops.color.Any,
    colorspace: std.meta.DeclEnum(vizops.color.types),
    colorFormat: vizops.color.fourcc.Value,
};

const BaseVTable = struct {
    loadBuffer: *const fn (*anyopaque, []const u8, LoadOptions) anyerror!*Font,
    deinit: ?*const fn (*anyopaque) void = null,
};

const FsVTable = struct {
    loadFile: ?*const fn (*anyopaque, std.fs.File, LoadOptions) anyerror!*Font = null,
};

pub const VTable = metap.structs.fields.mix(BaseVTable, if (@hasDecl(std.os.system, "fd_t")) FsVTable else struct {});

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn loadBuffer(self: *Self, buff: []const u8, options: LoadOptions) !*Font {
    return self.vtable.loadBuffer(self.ptr, buff, options);
}

pub inline fn loadFile(self: *Self, file: std.fs.File, options: LoadOptions) !*Font {
    if (@hasDecl(std.os.system, "fd_t")) {
        if (self.vtable.loadFile) |f| return f(self.ptr, file, options);
        return error.NotImplemented;
    }
    return error.NotSupported;
}

pub inline fn deinit(self: *Self) void {
    return if (self.vtable.deinit) |f| f(self.ptr) else {};
}
