const std = @import("std");
const metap = @import("metaplus").@"meta+";
const Sdk = @import("phantom-sdk");

pub const DisplayBackendType = metap.enums.fields.mix(metap.enums.fromDecls(@import("src/phantom/display/backends.zig")), Sdk.TypeFor(.displays));
pub const SceneBackendType = metap.enums.fields.mix(metap.enums.fromDecls(@import("src/phantom/scene/backends.zig")), Sdk.TypeFor(.scenes));

pub fn build(b: *std.Build) void {
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

    _ = b.addModule("vizops", .{
        .source_file = .{
            .path = vizops.builder.pathFromRoot(vizops.module("vizops").source_file.path),
        },
    });

    const metaplus = b.dependency("metaplus", .{
        .target = target,
        .optimize = optimize,
    });

    _ = b.addModule("meta+", .{
        .source_file = .{
            .path = metaplus.builder.pathFromRoot(metaplus.module("meta+").source_file.path),
        },
    });

    const sdk = b.dependency("phantom-sdk", .{
        .target = target,
        .optimize = optimize,
        .no_importer = no_importer,
    });

    const phantomOptions = b.addOptions();
    phantomOptions.addOption(bool, "no_importer", no_importer);

    var phantomDeps = std.ArrayList(std.Build.ModuleDependency).init(b.allocator);
    errdefer phantomDeps.deinit();

    phantomDeps.append(.{
        .name = "vizops",
        .module = vizops.module("vizops"),
    }) catch @panic("OOM");

    phantomDeps.append(.{
        .name = "meta+",
        .module = metaplus.module("meta+"),
    }) catch @panic("OOM");

    phantomDeps.append(.{
        .name = "phantom.options",
        .module = phantomOptions.createModule(),
    }) catch @panic("OOM");

    if (!no_importer) {
        phantomDeps.append(.{
            .name = "phantom.imports",
            .module = sdk.module("phantom.imports"),
        }) catch @panic("OOM");
    }

    const phantom = b.addModule("phantom", .{
        .source_file = .{ .path = b.pathFromRoot("src/phantom.zig") },
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
    if (!no_importer) unit_tests.addModule("phantom.imports", sdk.module("phantom.imports"));

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
