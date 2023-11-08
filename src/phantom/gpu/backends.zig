const root = @import("root");
const imports = if (@hasDecl(root, "dependencies")) struct {} else @import("phantom.imports").import(@import("../../phantom.zig"));

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantom, "gpuBackends")) root.phantomOptions.gpuBackends else struct {} else struct {};
pub usingnamespace if (@hasDecl(imports, "gpu")) if (@hasDecl(imports.gpu, "backends")) imports.gpu.backends else struct {} else struct {};
