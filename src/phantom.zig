const root = @import("root");
const imports = if (@hasDecl(root, "dependencies")) struct {} else @import("phantom.imports").import(@This());

pub const display = @import("phantom/display.zig");
pub const math = @import("phantom/math.zig");
pub const scene = @import("phantom/scene.zig");

pub const i18n = if (@hasDecl(imports, "i18n")) imports.i18n else @compileError("phantom.i18n module was not added to build.zig.zon");
