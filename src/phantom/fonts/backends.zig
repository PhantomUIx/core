const root = @import("root");

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantomOptions, "fontBackends")) root.phantomOptions.fontBackends else struct {} else struct {};
