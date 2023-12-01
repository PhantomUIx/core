const std = @import("std");
const metap = @import("meta+");
const Base = @import("base.zig");
const Self = @This();

const BaseVTable = struct {
    create: ?*const fn (*anyopaque, Base.Info) anyerror!*Base = null,
    readBuffer: *const fn (*anyopaque, []const u8) anyerror!*Base,
    writeBuffer: ?*const fn (*anyopaque, *Base, []u8) anyerror!usize = null,
    deinit: ?*const fn (*anyopaque) void = null,
};

const FsVTable = struct {
    readFile: ?*const fn (*anyopaque, std.fs.File) anyerror!*Base = null,
    writeFile: ?*const fn (*anyopaque, *Base, std.fs.File) anyerror!usize = null,
};

pub const VTable = metap.structs.fields.mix(BaseVTable, if (@hasDecl(std.os.system, "fd_t")) FsVTable else struct {});

ptr: *anyopaque,
vtable: *const VTable,

pub inline fn create(self: Self, info: Base.Info) !*Base {
    if (self.vtable.create) |f| return f(self.ptr, info);
}

pub inline fn readBuffer(self: Self, buff: []const u8) !*Base {
    return self.vtable.readBuffer(self.ptr, buff);
}

pub inline fn writeBuffer(self: Self, img: *Base, buff: []u8) !usize {
    if (self.vtable.writeBuffer) |f| return f(self.ptr, img, buff);
    return error.NotImplemented;
}

pub inline fn readFile(self: Self, file: std.fs.File) !*Base {
    if (@hasDecl(std.os.system, "fd_t")) {
        if (self.vtable.readFile) |f| return f(self.ptr, file);
        return error.NotImplemented;
    }
    return error.NotSupported;
}

pub inline fn writeFile(self: Self, img: *Base, file: std.fs.File) !usize {
    if (@hasDecl(std.os.system, "fd_t")) {
        if (self.vtable.writeFile) |f| return f(self.ptr, img, file);
        return error.NotImplemented;
    }
    return error.NotSupported;
}

pub inline fn deinit(self: Self) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
