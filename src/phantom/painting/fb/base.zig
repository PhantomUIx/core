const vizops = @import("vizops");
const Base = @This();

pub const Info = struct {
    res: vizops.vector.UsizeVector2,
    size: usize,
    depth: u8,
};

pub const VTable = struct {
    addr: *const fn (*anyopaque) anyerror!*anyopaque,
    info: *const fn (*anyopaque) Info,
    read: ?*const fn (*anyopaque, usize) anyerror![*]const u8 = null,
    write: ?*const fn (*anyopaque, usize, []const u8) anyerror!void = null,
    dupe: *const fn (*anyopaque) anyerror!*Base,
    commit: ?*const fn (*anyopaque) anyerror!void,
    deinit: ?*const fn (*anyopaque) void,
};

vtable: *const VTable,
ptr: *anyopaque,

pub inline fn addr(self: *Base) !*anyopaque {
    return self.vtable.addr(self.ptr);
}

pub inline fn info(self: *Base) Info {
    return self.vtable.info(self.ptr);
}

pub inline fn read(self: *Base, i: usize) ![*]const u8 {
    if (self.vtable.read) |f| return f(self.ptr, i);

    const inf = self.info();
    const ptr: [*]const u8 = @ptrCast(@alignCast(try self.addr()));
    return ptr[(inf.size * i)..inf.size];
}

pub inline fn write(self: *Base, i: usize, val: []const u8) !void {
    if (self.vtable.write) |f| return f(self.ptr, i, val);

    const inf = self.info();
    const ptr: [*]u8 = @ptrCast(@alignCast(try self.addr()));
    @memcpy(ptr[(inf.size * i)..val.len], val);
}

pub inline fn dupe(self: *Base) !*Base {
    return self.vtable.dupe(self.ptr);
}

pub inline fn commit(self: *Base) !void {
    if (self.vtable.commit) |f| return f(self.ptr);
}

pub inline fn deinit(self: *Base) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
