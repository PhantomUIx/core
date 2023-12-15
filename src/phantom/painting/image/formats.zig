const root = @import("root");
const imports = @import("../../importer.zig").imported;

pub usingnamespace if (@hasDecl(root, "phantomOptions")) if (@hasDecl(root.phantomOptions, "imageFormats")) root.phantomOptions.imageFormats else struct {} else struct {};
pub usingnamespace if (@hasDecl(imports, "painting")) if (@hasDecl(imports.painting, "image")) if (@hasDecl(imports.painting.image, "formats")) imports.painting.image.formats else struct {} else struct {} else struct {};
