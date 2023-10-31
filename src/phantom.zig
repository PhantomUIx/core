const root = @import("root");
const imports = if (@hasDecl(root, "dependencies")) struct {} else @import("phantom.imports");

pub const math = @import("phantom/math.zig");
pub const scene = @import("phantom/scene.zig");

pub usingnamespace if (@hasDecl(imports, "i18n")) struct {
    pub const i18n = imports.i18n;
} else struct {};
