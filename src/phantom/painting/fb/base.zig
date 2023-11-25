const std = @import("std");
const vizops = @import("vizops");
const Blt = @import("../../painting.zig").Blt;
const Base = @This();

pub const Info = struct {
    res: vizops.vector.UsizeVector2,
    colorspace: std.meta.DeclEnum(vizops.color.types),
    format: u32,

    pub fn size(self: Info) !usize {
        const fourcc = try vizops.color.fourcc.Value.decode(self.format);
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

    const src: [*]u8 = @ptrCast(@alignCast(switch (mode) {
        .from => try op.addr(),
        .to => try self.addr(),
    }));

    const src_info = switch (mode) {
        .from => op.info(),
        .to => self.info(),
    };

    const dest: [*]u8 = @ptrCast(@alignCast(switch (mode) {
        .from => try self.addr(),
        .to => try op.addr(),
    }));

    const dest_info = switch (mode) {
        .from => self.info(),
        .to => op.info(),
    };

    const src_color = try vizops.color.fourcc.Value.decode(src_info.format);
    const dest_color = try vizops.color.fourcc.Value.decode(dest_info.format);

    const width = @min(src_info.res.value[0], dest_info.res.value[0]);
    const height = @min(src_info.res.value[1], dest_info.res.value[1]);

    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const srci = y * src_color.channelCount() + x;
            const desti = y * dest_color.channelCount() + x;

            const srcbuff = src[srci..src_color.channelCount()];
            const destbuff = dest[desti..dest_color.channelCount()];

            const srcval = try vizops.color.readAnyBuffer(src_info.colorspace, src_color, srcbuff);
            try vizops.color.writeAnyBuffer(dest_color, destbuff, srcval);
        }
    }
}
