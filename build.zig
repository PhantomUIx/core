const std = @import("std");
const metap = @import("metaplus").@"meta+";

pub const Sdk = @import("src/phantom/sdk.zig");

pub const DisplayBackendType = metap.enums.fields.mix(metap.enums.fromDecls(@import("src/phantom/display/backends.zig")), Sdk.TypeFor(.displays));
pub const SceneBackendType = metap.enums.fields.mix(metap.enums.fromDecls(@import("src/phantom/scene/backends.zig")), Sdk.TypeFor(.scenes));
pub const ImageFormatType = metap.enums.fields.mix(metap.enums.fromDecls(@import("src/phantom/painting/image/formats.zig")), Sdk.TypeFor(.imageFormats));

fn addSourceFiles(
    b: *std.Build,
    fileOverrides: *std.StringHashMap([]const u8),
    rootSource: *[]const u8,
    phantomSource: *std.Build.Step.WriteFile,
    rootPath: []const u8,
) !void {
    var depSourceRoot = try std.fs.openDirAbsolute(b.pathJoin(&.{ rootPath, "phantom" }), .{ .iterate = true });
    defer depSourceRoot.close();

    var walker = try depSourceRoot.walk(b.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .directory) continue;

        const entryPath = b.pathJoin(&.{ rootPath, "phantom", entry.path });
        var entrySource = try Sdk.readAll(b.allocator, entryPath);
        errdefer b.allocator.free(entrySource);

        const entrypointRel = try std.fs.path.relative(b.allocator, std.fs.path.dirname(entryPath).?, b.pathJoin(&.{ rootPath, "phantom.zig" }));
        defer b.allocator.free(entrypointRel);

        const entrySourceOrig = entrySource;
        entrySource = try std.mem.replaceOwned(u8, b.allocator, entrySourceOrig, "@import(\"phantom\")", b.fmt("@import(\"{s}\")", .{entrypointRel}));
        b.allocator.free(entrySourceOrig);

        if (fileOverrides.getPtr(entry.path)) |sourceptr| {
            const fullSource = try Sdk.updateSource(b.allocator, sourceptr.*, entrySource);
            errdefer b.allocator.free(fullSource);

            b.allocator.free(sourceptr.*);
            sourceptr.* = fullSource;
        } else {
            const origPath = b.pathFromRoot(b.pathJoin(&.{ "src/phantom", entry.path }));
            if (Sdk.readAll(b.allocator, origPath) catch null) |origSource| {
                defer b.allocator.free(origSource);

                const fullSource = try Sdk.updateSource(b.allocator, origSource, entrySource);
                errdefer b.allocator.free(fullSource);

                try fileOverrides.put(try b.allocator.dupe(u8, entry.path), fullSource);
                b.allocator.free(entrySource);
            } else {
                _ = phantomSource.add(b.pathJoin(&.{ "phantom", entry.path }), entrySource);
            }
        }
    }

    const src = try Sdk.readAll(b.allocator, b.pathJoin(&.{ rootPath, "phantom.zig" }));
    defer b.allocator.free(src);

    const fullSource = try Sdk.updateSource(b.allocator, rootSource.*, src);
    errdefer b.allocator.free(fullSource);

    b.allocator.free(rootSource.*);
    rootSource.* = fullSource;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const no_docs = b.option(bool, "no-docs", "skip installing documentation") orelse false;
    const no_importer = b.option(bool, "no-importer", "disables the import system (not recommended)") orelse false;
    const display_backend = b.option(DisplayBackendType, "display-backend", "The display backend to use for the example") orelse .headless;
    const scene_backend = b.option(SceneBackendType, "scene-backend", "The scene backend to use for the example") orelse .headless;

    const vizops = b.dependency("vizops", .{
        .target = target,
        .optimize = optimize,
    });

    const metaplus = b.dependency("metaplus", .{
        .target = target,
        .optimize = optimize,
    });

    const anyplus = b.dependency("any+", .{
        .target = target,
        .optimize = optimize,
    });

    const phantomOptions = b.addOptions();
    phantomOptions.addOption(bool, "no_importer", no_importer);

    var phantomDeps = std.ArrayList(std.Build.Module.Import).init(b.allocator);
    errdefer phantomDeps.deinit();

    try phantomDeps.append(.{
        .name = "vizops",
        .module = vizops.module("vizops"),
    });

    try phantomDeps.append(.{
        .name = "meta+",
        .module = metaplus.module("meta+"),
    });

    try phantomDeps.append(.{
        .name = "any+",
        .module = anyplus.module("any+"),
    });

    try phantomDeps.append(.{
        .name = "phantom.options",
        .module = phantomOptions.createModule(),
    });

    const phantomSource = b.addWriteFiles();

    var fileOverrides = std.StringHashMap([]const u8).init(b.allocator);
    defer fileOverrides.deinit();

    var rootSource = try Sdk.readAll(b.allocator, b.pathFromRoot("src/phantom.zig"));
    defer b.allocator.free(rootSource);

    if (!no_importer) {
        inline for (Sdk.availableDepenencies) |dep| {
            const pkg = @field(@import("root").dependencies.packages, dep[1]);
            const pkgdep = b.dependencyInner(dep[0], pkg.build_root, if (@hasDecl(pkg, "build_zig")) pkg.build_zig else null, pkg.deps, .{
                .target = target,
                .optimize = optimize,
                .@"no-importer" = true,
            });

            const depSourceRootPath = b.pathJoin(&.{ pkg.build_root, "src" });
            try addSourceFiles(b, &fileOverrides, &rootSource, phantomSource, depSourceRootPath);

            var iter = pkgdep.module(dep[0]).import_table.iterator();
            while (iter.next()) |entry| {
                var alreadyExists = false;
                for (phantomDeps.items) |i| {
                    if (std.mem.eql(u8, i.name, entry.key_ptr.*)) {
                        alreadyExists = true;
                        break;
                    }
                }

                if (!alreadyExists or !std.mem.eql(u8, entry.key_ptr.*, "phantom")) {
                    try phantomDeps.append(.{
                        .name = entry.key_ptr.*,
                        .module = entry.value_ptr.*,
                    });
                }
            }
        }
    }

    if (b.option([]const u8, "import-module", "inject a module to be imported")) |importModuleString| {
        const modulePathLen = std.mem.indexOf(u8, importModuleString, ":") orelse importModuleString.len;
        const modulePath = importModuleString[0..modulePathLen];

        try addSourceFiles(b, &fileOverrides, &rootSource, phantomSource, modulePath);

        if (modulePathLen < importModuleString.len) {
            const imports = try Sdk.ModuleImport.decode(b.allocator, importModuleString[(modulePathLen + 1)..]);
            defer imports.deinit();

            for (imports.value) |dep| {
                var alreadyExists = false;
                for (phantomDeps.items) |i| {
                    if (std.mem.eql(u8, i.name, dep.name)) {
                        alreadyExists = true;
                        break;
                    }

                    if (!alreadyExists or !std.mem.eql(u8, dep.name, "phantom")) {
                        try phantomDeps.append(.{
                            .name = dep.name,
                            .module = try dep.createModule(b, target, optimize),
                        });
                    }
                }
            }
        }
    }

    var phantomSourceRoot = try std.fs.openDirAbsolute(b.pathFromRoot("src/phantom"), .{ .iterate = true });
    defer phantomSourceRoot.close();

    var walker = try phantomSourceRoot.walk(b.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .directory) continue;

        const entryPath = b.pathJoin(&.{ "phantom", entry.path });

        if (fileOverrides.get(entry.path)) |source| {
            _ = phantomSource.add(entryPath, source);
        } else {
            _ = phantomSource.addCopyFile(.{
                .path = b.pathFromRoot(b.pathJoin(&.{ "src/phantom", entry.path })),
            }, entryPath);
        }
    }

    const phantom = b.addModule("phantom", .{
        .root_source_file = phantomSource.add("phantom.zig", rootSource),
        .imports = phantomDeps.items,
    });

    const step_test = b.step("test", "Run all unit tests");

    const unit_tests = b.addTest(.{
        .root_source_file = phantom.root_source_file.?,
        .target = target,
        .optimize = optimize,
    });

    for (phantomDeps.items) |dep| {
        unit_tests.root_module.addImport(dep.name, dep.module);
    }

    const run_unit_tests = b.addRunArtifact(unit_tests);
    step_test.dependOn(&run_unit_tests.step);
    b.installArtifact(unit_tests);

    const exe_options = b.addOptions();
    exe_options.addOption(DisplayBackendType, "display_backend", display_backend);
    exe_options.addOption(SceneBackendType, "scene_backend", scene_backend);

    const exe_example = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{
            .path = b.pathFromRoot("src/example.zig"),
        },
        .target = target,
        .optimize = optimize,
    });

    exe_example.root_module.addImport("phantom", phantom);
    exe_example.root_module.addImport("vizops", vizops.module("vizops"));
    exe_example.root_module.addImport("options", exe_options.createModule());
    b.installArtifact(exe_example);

    const exe_example_libc = b.addExecutable(.{
        .name = "example-libc",
        .root_source_file = .{
            .path = b.pathFromRoot("src/example.zig"),
        },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe_example_libc.root_module.addImport("phantom", phantom);
    exe_example_libc.root_module.addImport("vizops", vizops.module("vizops"));
    exe_example_libc.root_module.addImport("options", exe_options.createModule());
    b.installArtifact(exe_example_libc);

    if (!no_docs) {
        const docs = b.addInstallDirectory(.{
            .source_dir = unit_tests.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });

        b.getInstallStep().dependOn(&docs.step);
    }
}
