const std = @import("std");

const AvailableDep = struct { []const u8, []const u8 };
const AvailableDeps = []const AvailableDep;

pub const ModuleImport = struct {
    name: []const u8,
    source: []const u8,
    dependencies: []const ModuleImport = &.{},

    pub const Error = error{ MakeFailed, MakeSkipped } || std.mem.Allocator.Error || std.fs.File.OpenError || std.os.ReadError;

    const b64Codec = std.base64.standard_no_pad;

    pub fn init(value: []const std.Build.Module.Import, path: []const u8, alloc: std.mem.Allocator) ![]const u8 {
        const list = try initList(value, alloc);
        defer alloc.free(list);

        const imports = try encode(list, alloc);
        defer alloc.free(imports);

        return try std.fmt.allocPrint(alloc, "{s}:{s}", .{ path, imports });
    }

    pub fn create(name: []const u8, module: *std.Build.Module) Error!ModuleImport {
        if (module.root_source_file.? == .generated) {
            var prog = std.Progress{};
            var node = prog.start(name, 1);
            defer node.end();

            try module.root_source_file.?.generated.step.make(node);
        }

        return .{
            .name = name,
            .source = module.root_source_file.?.getPath(module.owner),
            .dependencies = try initTable(module.import_table, module.owner.allocator),
        };
    }

    pub fn initTable(tbl: std.StringArrayHashMapUnmanaged(*std.Build.Module), alloc: std.mem.Allocator) Error![]const ModuleImport {
        const value = try alloc.alloc(ModuleImport, tbl.count());
        errdefer alloc.free(value);

        var iter = tbl.iterator();
        var i: usize = 0;
        while (iter.next()) |entry| {
            value[i] = try create(entry.key_ptr.*, entry.value_ptr.*);
            i += 1;
        }
        return value;
    }

    pub fn initList(list: []const std.Build.Module.Import, alloc: std.mem.Allocator) Error![]const ModuleImport {
        const value = try alloc.alloc(ModuleImport, list.len);
        errdefer alloc.free(value);

        for (list, 0..) |entry, i| {
            value[i] = try create(entry.name, entry.module);
        }
        return value;
    }

    pub fn decode(alloc: std.mem.Allocator, str: []const u8) !std.json.Parsed([]const ModuleImport) {
        const buffer = try alloc.alloc(u8, try b64Codec.Decoder.calcSizeForSlice(str));
        defer alloc.free(buffer);

        try b64Codec.Decoder.decode(buffer, str);
        return try std.json.parseFromSlice([]const ModuleImport, alloc, buffer, .{
            .allocate = .alloc_always,
        });
    }

    pub fn encode(list: []const ModuleImport, alloc: std.mem.Allocator) ![]const u8 {
        const str = try std.json.stringifyAlloc(alloc, list, .{
            .emit_null_optional_fields = false,
            .whitespace = .minified,
        });
        defer alloc.free(str);

        const buffer = try alloc.alloc(u8, b64Codec.Encoder.calcSize(str.len));
        errdefer alloc.free(buffer);

        _ = b64Codec.Encoder.encode(buffer, str);
        return buffer;
    }

    pub fn createModule(self: *const ModuleImport, b: *std.Build, target: ?std.Build.ResolvedTarget, optimize: ?std.builtin.OptimizeMode) !*std.Build.Module {
        if (b.modules.get(self.name)) |value| return value;

        var imports = try std.ArrayList(std.Build.Module.Import).initCapacity(b.allocator, self.dependencies.len);
        errdefer imports.deinit();

        for (self.dependencies) |dep| {
            imports.appendAssumeCapacity(.{
                .name = dep.name,
                .module = try dep.createModule(b, target, optimize),
            });
        }

        const module = b.createModule(.{
            .root_source_file = .{
                .path = self.source,
            },
            .imports = imports.items,
            .target = target,
            .optimize = optimize,
        });

        try b.modules.put(b.dupe(self.name), module);
        return module;
    }
};

pub const PhantomModule = struct {
    // TODO: expected version of core
    provides: ?Provides = null,

    pub const Provides = struct {
        scenes: ?[]const []const u8 = null,
        displays: ?[]const []const u8 = null,
        platforms: ?[]const []const u8 = null,
        imageFormats: ?[]const []const u8 = null,

        pub fn value(self: Provides, kind: std.meta.FieldEnum(Provides)) []const []const u8 {
            return (switch (kind) {
                .scenes => self.scenes,
                .displays => self.displays,
                .platforms => self.platforms,
                .imageFormats => self.imageFormats,
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

pub fn updateSource(alloc: std.mem.Allocator, a: []const u8, b: []const u8) ![]const u8 {
    var lines = std.ArrayList(u8).init(alloc);
    errdefer lines.deinit();
    try lines.appendSlice(a);

    var bIter = std.mem.splitAny(u8, b, "\n");
    while (bIter.next()) |bline| {
        if (std.mem.indexOf(u8, a, bline) != null) continue;
        try lines.appendSlice(bline);
    }
    return lines.items;
}
