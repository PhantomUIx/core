const root = @import("root");

pub const headless = @import("backends/headless.zig");
pub const fb = @import("backends/fb.zig");

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantomOptions, "sceneBackends")) root.phantomOptions.sceneBackends else struct {} else struct {};
