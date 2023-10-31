const std = @import("std");
const metap = @import("metaplus").@"meta+";

pub const BackendType = metap.enums.fromDecls(@import("src/phantom/scene/backends.zig"));

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const no_docs = b.option(bool, "no-docs", "skip installing documentation") orelse false;
    const backend = b.option(BackendType, "backend", "The backend to use for the example") orelse .headless;

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

    const gen = b.addWriteFiles();
    var phantom_imports_data = std.ArrayList(u8).init(b.allocator);
    var phantom_imports_deps = std.ArrayList(std.Build.ModuleDependency).init(b.allocator);

    const modules = [_][]const []const u8{
        &[_][]const u8{ "scene", "backends" },
        &[_][]const u8{"i18n"},
    };

    for (modules) |mod| {
        for (mod) |p| {
            phantom_imports_data.writer().print(
                \\pub const {s} = struct {{
            , .{p}) catch |e| @panic(@errorName(e));
        }

        for (@import("root").dependencies.root_deps) |dep| {
            if (std.mem.startsWith(u8, dep[0], "phantom-")) {
                phantom_imports_data.writer().print(
                    \\pub usingnamespace blk: {{
                    \\  const imports = @import("root.{s}");
                , .{dep[0]}) catch |e| @panic(@errorName(e));

                for (mod, 0..) |p, i| {
                    phantom_imports_data.writer().print(
                        \\if (@hasDecl(imports{s}, "{s}")) {{
                    , .{ if (i == 0) "" else b.fmt(".{s}", .{std.mem.join(b.allocator, ".", mod[0..i]) catch |e| @panic(@errorName(e))}), p }) catch |e| @panic(@errorName(e));
                }

                phantom_imports_data.writer().print(
                    \\break :blk imports.{s};
                , .{std.mem.join(b.allocator, ".", mod) catch |e| @panic(@errorName(e))}) catch |e| @panic(@errorName(e));

                for (mod) |_| {
                    phantom_imports_data.writer().print(
                        \\}}
                    , .{}) catch |e| @panic(@errorName(e));
                }

                phantom_imports_data.writer().print(
                    \\break :blk struct {{}};
                    \\}};
                , .{}) catch |e| @panic(@errorName(e));
            }
        }

        for (mod) |_| {
            phantom_imports_data.writer().print(
                \\}};
            , .{}) catch |e| @panic(@errorName(e));
        }
    }

    for (@import("root").dependencies.root_deps) |dep| {
        if (std.mem.startsWith(u8, dep[0], "phantom-")) {
            phantom_imports_deps.append(.{
                .name = dep[0],
                .module = b.dependency(dep[0], .{
                    .target = target,
                    .optimize = optimize,
                }).module(dep[0]),
            }) catch |e| @panic(@errorName(e));
        }
    }

    const phantom_imports_gen = gen.add("phantom.imports.zig", phantom_imports_data.items);
    const phantom_imports = b.addModule("phantom.imports", .{
        .source_file = phantom_imports_gen,
        .dependencies = phantom_imports_deps.items,
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
            .module = phantom_imports,
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
    unit_tests.addModule("phantom.imports", b.addModule("phantom.imports", .{
        .source_file = phantom_imports_gen,
        .dependencies = phantom_imports_deps.items,
    }));

    const run_unit_tests = b.addRunArtifact(unit_tests);
    step_test.dependOn(&run_unit_tests.step);

    const exe_options = b.addOptions();
    exe_options.addOption(BackendType, "backend", backend);

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

    if (!no_docs) {
        const docs = b.addInstallDirectory(.{
            .source_dir = unit_tests.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });

        b.getInstallStep().dependOn(&docs.step);
    }
}
