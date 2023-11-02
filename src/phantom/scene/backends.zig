const root = @import("root");
const imports = if (@hasDecl(root, "dependencies")) struct {} else @import("phantom.imports").Import(@import("../../phantom.zig"));

pub const headless = @import("backends/headless.zig");
pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantom, "backends")) root.phantomOptions.backends else struct {} else struct {};
pub usingnamespace if (@hasDecl(imports, "scene")) if (@hasDecl(imports.scene, "backends")) imports.scene.backends else struct {} else struct {};
