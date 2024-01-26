const root = @import("root");

pub const std = @import("backends/std.zig");

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantomOptions, "platformBackends")) root.phantomOptions.platformBackends else struct {} else struct {};
