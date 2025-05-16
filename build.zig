const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigimg = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const z2d = b.dependency("z2d", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.addModule("phantom", .{
        .root_source_file = b.path("lib/phantom.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "zigimg",
                .module = zigimg.module("zigimg"),
            },
            .{
                .name = "z2d",
                .module = z2d.module("z2d"),
            },
        },
    });

    const autodoc_test = b.addObject(.{
        .name = "phantom",
        .root_module = module,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = autodoc_test.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "doc/phantom",
    });

    b.getInstallStep().dependOn(&install_docs.step);

    const step_test = b.step("test", "Run unit tests");

    const test_exe = b.addTest(.{
        .target = target,
        .optimize = optimize,
        .root_module = module,
    });

    const test_run = b.addRunArtifact(test_exe);
    step_test.dependOn(&test_run.step);
}
