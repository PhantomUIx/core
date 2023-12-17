const std = @import("std");
const metap = @import("metaplus").@"meta+";

pub const Sdk = @import("src/phantom/sdk.zig");

pub const DisplayBackendType = metap.enums.fields.mix(metap.enums.fromDecls(@import("src/phantom/display/backends.zig")), Sdk.TypeFor(.displays));
pub const SceneBackendType = metap.enums.fields.mix(metap.enums.fromDecls(@import("src/phantom/scene/backends.zig")), Sdk.TypeFor(.scenes));

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

    var phantomDeps = std.ArrayList(std.Build.ModuleDependency).init(b.allocator);
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

    var rootSource = std.ArrayList(u8).init(b.allocator);
    defer rootSource.deinit();

    {
        const src = try Sdk.readAll(b.allocator, b.pathFromRoot("src/phantom.zig"));
        defer b.allocator.free(src);
        try rootSource.appendSlice(src);
    }

    if (!no_importer) {
        inline for (Sdk.availableDepenencies) |dep| {
            const pkg = @field(@import("root").dependencies.packages, dep[1]);
            const depSourceRootPath = b.pathJoin(&.{ pkg.build_root, "src/phantom" });
            var depSourceRoot = try std.fs.openDirAbsolute(depSourceRootPath, .{ .iterate = true });
            defer depSourceRoot.close();

            var walker = try depSourceRoot.walk(b.allocator);
            defer walker.deinit();

            while (try walker.next()) |entry| {
                if (entry.kind == .directory) continue;

                const entryPath = b.pathJoin(&.{ depSourceRootPath, entry.path });
                const entrySource = try Sdk.readAll(b.allocator, entryPath);
                errdefer b.allocator.free(entrySource);

                if (fileOverrides.getPtr(entry.path)) |sourceptr| {
                    const fullSource = try std.mem.concat(b.allocator, u8, &.{ sourceptr.*, entrySource });
                    errdefer b.allocator.free(fullSource);

                    b.allocator.free(sourceptr.*);
                    sourceptr.* = fullSource;
                } else {
                    const origPath = b.pathFromRoot(b.pathJoin(&.{ "src/phantom", entry.path }));
                    const origSource = try Sdk.readAll(b.allocator, origPath);
                    defer b.allocator.free(origSource);

                    const fullSource = try std.mem.concat(b.allocator, u8, &.{ origSource, entrySource });
                    errdefer b.allocator.free(fullSource);

                    try fileOverrides.put(entry.path, fullSource);
                }
            }

            const src = try Sdk.readAll(b.allocator, b.pathJoin(&.{ pkg.build_root, "src/phantom.zig" }));
            defer b.allocator.free(src);
            try rootSource.appendSlice(src);
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
        .source_file = phantomSource.add("phantom.zig", rootSource.items),
        .dependencies = phantomDeps.items,
    });

    const step_test = b.step("test", "Run all unit tests");

    const unit_tests = b.addTest(.{
        .root_source_file = .{
            .path = b.pathFromRoot("src/phantom.zig"),
        },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addModule("vizops", vizops.module("vizops"));
    unit_tests.addModule("meta+", metaplus.module("meta+"));
    unit_tests.addModule("phantom.options", phantomOptions.createModule());

    const run_unit_tests = b.addRunArtifact(unit_tests);
    step_test.dependOn(&run_unit_tests.step);

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

    exe_example.addModule("phantom", phantom);
    exe_example.addModule("vizops", vizops.module("vizops"));
    exe_example.addOptions("options", exe_options);
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

    exe_example_libc.addModule("phantom", phantom);
    exe_example_libc.addModule("vizops", vizops.module("vizops"));
    exe_example_libc.addOptions("options", exe_options);
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
