const root = @import("root");

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantomOptions, "gpuBackends")) root.phantomOptions.gpuBackends else struct {} else struct {};
