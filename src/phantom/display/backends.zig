const root = @import("root");
const imports = @import("../importer.zig").imported;

pub const headless = @import("backends/headless.zig");

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantom, "displayBackends")) root.phantomOptions.displayBackends else struct {} else struct {};
pub usingnamespace if (@hasDecl(imports, "display")) if (@hasDecl(imports.display, "backends")) imports.display.backends else struct {} else struct {};
