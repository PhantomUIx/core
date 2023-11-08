const std = @import("std");
const Allocator = std.mem.Allocator;
const Base = @import("base.zig");
const Device = @import("device.zig");
const Manager = @This();

allocator: Allocator,
backends: []*Base,

pub fn create(alloc: Allocator) Allocator.Error!*Manager {
    const backends = @import("backends.zig");

    const self = try alloc.create(Manager);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .backends = try alloc.alloc(*Base, std.meta.declarations(backends).len),
    };
    errdefer alloc.free(self.backends);

    inline for (std.meta.declarations(backends), 0..) |decl, i| {
        const backend = @field(backends, decl.name);

        self.backends[i] = try backend.create(.{
            .allocator = alloc,
        });
        errdefer self.backends[i].deinit();
    }
    return self;
}

pub fn deinit(self: *Manager) void {
    for (self.backends) |backend| backend.deinit();
    self.allocator.free(self.backends);
    self.allocator.destroy(self);
}

pub fn dupe(self: *Manager) !*Manager {
    const d = try self.allocator.create(Manager);
    errdefer self.allocator.destroy(d);

    d.* = .{
        .allocator = self.allocator,
        .backends = try self.allocator.alloc(*Base, self.backends.len),
    };
    errdefer self.allocator.free(d.backends);

    for (self.backends, &d.backends) |b, *bd| {
        bd.* = try b.dupe();
        errdefer bd.deinit();
    }
    return d;
}

pub fn devices(self: *Manager) !std.ArrayList(*Device) {
    var list = std.ArrayList(*Device).init(self.allocator);
    errdefer list.deinit();

    for (self.backends) |backend| {
        var blist = try backend.list();
        defer blist.deinit();

        for (blist.items) |dev| try list.append(try dev.dupe());
    }
    return list;
}
