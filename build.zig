const std = @import("std");
const metap = @import("metaplus").@"meta+";

pub const DisplayBackendType = metap.enums.fromDecls(@import("src/phantom/display/backends.zig"));
pub const SceneBackendType = metap.enums.fromDecls(@import("src/phantom/scene/backends.zig"));

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const no_docs = b.option(bool, "no-docs", "skip installing documentation") orelse false;
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
    });

    const phantom = b.addModule("phantom", .{
        .source_file = .{ .path = b.pathFromRoot("src/phantom.zig") },
        .dependencies = &.{ .{
            .name = "vizops",
            .module = vizops.module("vizops"),
        }, .{
            .name = "meta+",
            .module = metaplus.module("meta+"),
        }, .{
            .name = "phantom.imports",
            .module = sdk.module("phantom.imports"),
        } },
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
    unit_tests.addModule("phantom.imports", sdk.module("phantom.imports"));

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
