const root = @import("root");
const imports = @import("../importer.zig").imported;

pub const headless = @import("backends/headless.zig");
pub const fb = @import("backends/fb.zig");

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantomOptions, "sceneBackends")) root.phantomOptions.sceneBackends else struct {} else struct {};
pub usingnamespace if (@hasDecl(imports, "scene")) if (@hasDecl(imports.scene, "backends")) imports.scene.backends else struct {} else struct {};
