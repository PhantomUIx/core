const root = @import("root");
const imports = @import("../importer.zig").imported;

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantom, "gpuBackends")) root.phantomOptions.gpuBackends else struct {} else struct {};
pub usingnamespace if (@hasDecl(imports, "gpu")) if (@hasDecl(imports.gpu, "backends")) imports.gpu.backends else struct {} else struct {};
