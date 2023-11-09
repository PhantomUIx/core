const vizops = @import("vizops");
const Blt = @import("../../painting.zig").Blt;
const Base = @This();

pub const Info = struct {
    res: vizops.vector.UsizeVector2,
    format: u32,

    pub fn size(self: Info) !usize {
        const fourcc = try vizops.fourcc.Value.decode(self.format);
        return fourcc.width() * @reduce(.Mul, self.res.value);
    }
};

pub const VTable = struct {
    lock: ?*const fn (*anyopaque) anyerror!void = null,
    unlock: ?*const fn (*anyopaque) void = null,
    addr: *const fn (*anyopaque) anyerror!*anyopaque,
    info: *const fn (*anyopaque) Info,
    read: ?*const fn (*anyopaque, usize) anyerror![*]const u8 = null,
    write: ?*const fn (*anyopaque, usize, []const u8) anyerror!void = null,
    dupe: *const fn (*anyopaque) anyerror!*Base,
    commit: ?*const fn (*anyopaque) anyerror!void = null,
    deinit: ?*const fn (*anyopaque) void = null,
    blt: ?*const fn (*anyopaque, Blt, *Base) anyerror!void,
};

vtable: *const VTable,
ptr: *anyopaque,

pub inline fn lock(self: *Base) anyerror!void {
    if (self.vtable.lock) |f| try f(self.ptr);
}

pub inline fn unlock(self: *Base) void {
    if (self.vtable.unlock) |f| f(self.ptr);
}

pub inline fn addr(self: *Base) !*anyopaque {
    return self.vtable.addr(self.ptr);
}

pub inline fn info(self: *Base) Info {
    return self.vtable.info(self.ptr);
}

pub inline fn read(self: *Base, i: usize) ![*]const u8 {
    if (self.vtable.read) |f| return f(self.ptr, i);

    const inf = self.info();
    const size = try inf.size();
    const ptr: [*]const u8 = @ptrCast(@alignCast(try self.addr()));
    return ptr[(size * i)..size];
}

pub inline fn write(self: *Base, i: usize, val: []const u8) !void {
    if (self.vtable.write) |f| return f(self.ptr, i, val);

    const inf = self.info();
    const size = try inf.size();
    const ptr: [*]u8 = @ptrCast(@alignCast(try self.addr()));
    @memcpy(ptr[(size * i)..val.len], val);
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

pub inline fn blt(self: *Base, mode: Blt, op: *Base) !void {
    if (self.vtable.blt) |f| return f(self.ptr, mode, op);

    // TODO: we should check infos and ensure they are compatible.

    const src: [*]u8 = @ptrCast(@alignCast(switch (mode) {
        .from => try op.addr(),
        .to => try self.addr(),
    }));

    const src_size = switch (mode) {
        .from => try op.info().size(),
        .to => try self.info().size(),
    };

    const dest: [*]u8 = @ptrCast(@alignCast(switch (mode) {
        .from => try self.addr(),
        .to => try op.addr(),
    }));

    const dest_size = switch (mode) {
        .from => try self.info().size(),
        .to => try op.info().size(),
    };

    @memcpy(dest[0..dest_size], src[0..src_size]);
}
