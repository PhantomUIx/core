const std = @import("std");

const AvailableDep = struct { []const u8, []const u8 };
const AvailableDeps = []const AvailableDep;

pub const PhantomModule = struct {
    // TODO: expected version of core
    provides: ?Provides = null,

    pub const Provides = struct {
        scenes: ?[]const []const u8 = null,
        displays: ?[]const []const u8 = null,

        pub fn value(self: Provides, kind: std.meta.FieldEnum(Provides)) []const []const u8 {
            return (switch (kind) {
                .scenes => self.scenes,
                .displays => self.displays,
            }) orelse &[_][]const u8{};
        }

        pub fn count(self: Provides, kind: std.meta.FieldEnum(Provides)) usize {
            return self.value(kind).len;
        }
    };

    pub fn getProvider(self: PhantomModule) Provides {
        return if (self.provides) |value| value else .{};
    }
};

pub const availableDepenencies = blk: {
    const buildDeps = @import("root").dependencies;
    var count: usize = 0;
    for (buildDeps.root_deps) |dep| {
        const pkg = @field(buildDeps.packages, dep[1]);
        if (@hasDecl(pkg, "build_zig")) {
            const buildZig = pkg.build_zig;
            if (@hasDecl(buildZig, "phantomModule") and @TypeOf(@field(buildZig, "phantomModule")) == PhantomModule) {
                count += 1;
            }
        }
    }

    var i: usize = 0;
    var deps: [count]AvailableDep = undefined;
    for (buildDeps.root_deps) |dep| {
        const pkg = @field(buildDeps.packages, dep[1]);
        if (@hasDecl(pkg, "build_zig")) {
            const buildZig = pkg.build_zig;
            if (@hasDecl(buildZig, "phantomModule") and @TypeOf(@field(buildZig, "phantomModule")) == PhantomModule) {
                deps[i] = dep;
                i += 1;
            }
        }
    }
    break :blk deps;
};

pub fn TypeFor(comptime kind: std.meta.FieldEnum(PhantomModule.Provides)) type {
    const buildDeps = @import("root").dependencies;

    var fieldCount: usize = 0;
    for (buildDeps.root_deps) |dep| {
        const pkg = @field(buildDeps.packages, dep[1]);
        if (@hasDecl(pkg, "build_zig")) {
            const buildZig = pkg.build_zig;
            if (@hasDecl(buildZig, "phantomModule") and @TypeOf(@field(buildZig, "phantomModule")) == PhantomModule) {
                const mod = buildZig.phantomModule;
                fieldCount += mod.getProvider().count(kind);
            }
        }
    }

    if (fieldCount == 0) {
        return @Type(.{
            .Enum = .{
                .tag_type = u0,
                .fields = &.{},
                .decls = &.{},
                .is_exhaustive = true,
            },
        });
    }

    var fields: [fieldCount]std.builtin.Type.EnumField = undefined;
    var i: usize = 0;
    for (buildDeps.root_deps) |dep| {
        const pkg = @field(buildDeps.packages, dep[1]);
        if (@hasDecl(pkg, "build_zig")) {
            const buildZig = pkg.build_zig;
            if (@hasDecl(buildZig, "phantomModule") and @TypeOf(@field(buildZig, "phantomModule")) == PhantomModule) {
                const mod = buildZig.phantomModule;

                for (mod.getProvider().value(kind)) |name| {
                    fields[i] = .{
                        .name = name,
                        .value = i,
                    };
                    i += 1;
                }
            }
        }
    }

    return @Type(.{
        .Enum = .{
            .tag_type = std.math.IntFittingRange(0, fields.len - 1),
            .fields = &fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
}

pub fn readAll(alloc: std.mem.Allocator, path: []const u8) ![]const u8 {
    var file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();
    return try file.readToEndAlloc(alloc, (try file.metadata()).size());
}

pub fn updateSource(alloc: std.mem.Allocator, a: []const u8, b: []const u8) []const u8 {
    return if (std.mem.eql(u8, a, b)) try alloc.dupe(u8, a) else try std.mem.concat(alloc, u8, &.{ a, b });
}
