const std = @import("std");
const vizops = @import("vizops");
const Blt = @import("../../painting.zig").Blt;
const Base = @This();

pub const Info = struct {
    res: vizops.vector.UsizeVector2,
    colorspace: std.meta.DeclEnum(vizops.color.types),
    colorFormat: vizops.color.fourcc.Value,

    pub fn size(self: Info) usize {
        return self.colorFormat.width() * @reduce(.Mul, self.res.value);
    }
};

pub const VTable = struct {
    lock: ?*const fn (*anyopaque) anyerror!void = null,
    unlock: ?*const fn (*anyopaque) void = null,
    addr: *const fn (*anyopaque) anyerror!*anyopaque,
    info: *const fn (*anyopaque) Info,
    read: ?*const fn (*anyopaque, usize, []u8) anyerror!void = null,
    write: ?*const fn (*anyopaque, usize, []const u8) anyerror!void = null,
    dupe: *const fn (*anyopaque) anyerror!*Base,
    commit: ?*const fn (*anyopaque) anyerror!void = null,
    deinit: ?*const fn (*anyopaque) void = null,
    blt: ?*const fn (*anyopaque, Blt, *Base) anyerror!void,
};

allocator: std.mem.Allocator,
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

pub inline fn read(self: *Base, i: usize, buf: []u8) anyerror!void {
    if (self.vtable.read) |f| return f(self.ptr, i, buf);

    const end = i + buf.len;

    const ptr: [*]const u8 = @ptrCast(@alignCast(try self.addr()));
    @memcpy(buf, ptr[i..end]);
}

pub inline fn write(self: *Base, i: usize, val: []const u8) !void {
    if (self.vtable.write) |f| return f(self.ptr, i, val);

    const ptr: [*]volatile u8 = @ptrCast(@alignCast(try self.addr()));
    @memcpy(ptr[i..(i + val.len)], val);
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

    const src_info = switch (mode) {
        .from => op.info(),
        .to => self.info(),
    };

    const dest_info = switch (mode) {
        .from => self.info(),
        .to => op.info(),
    };

    const width = @min(src_info.res.value[0], dest_info.res.value[0]);
    const height = @min(src_info.res.value[1], dest_info.res.value[1]);

    const srcbuff = try self.allocator.alloc(u8, @divExact(src_info.colorFormat.width(), 8));
    defer self.allocator.free(srcbuff);

    const destbuff = try self.allocator.alloc(u8, @divExact(dest_info.colorFormat.width(), 8));
    defer self.allocator.free(destbuff);

    const srcStride = srcbuff.len * src_info.res.value[0];
    const destStride = destbuff.len * dest_info.res.value[0];

    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const srci = y * srcStride + x * srcbuff.len;
            const desti = y * destStride + x * destbuff.len;

            try switch (mode) {
                .from => op.read(srci, srcbuff),
                .to => self.read(srci, srcbuff),
            };

            const srcval = try vizops.color.readAnyBuffer(src_info.colorspace, src_info.colorFormat, srcbuff);
            try vizops.color.writeAnyBuffer(dest_info.colorFormat, destbuff, srcval);

            try switch (mode) {
                .from => self.write(desti, destbuff),
                .to => op.write(desti, destbuff),
            };
        }
    }
}
