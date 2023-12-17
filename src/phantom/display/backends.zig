const root = @import("root");

pub const headless = @import("backends/headless.zig");

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantomOptions, "displayBackends")) root.phantomOptions.displayBackends else struct {} else struct {};
