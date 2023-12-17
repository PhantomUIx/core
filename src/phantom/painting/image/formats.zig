const root = @import("root");

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantomOptions, "imageFormats")) root.phantomOptions.imageFormats else struct {} else struct {};
