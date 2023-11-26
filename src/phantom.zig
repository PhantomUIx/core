const root = @import("root");
const imports = @import("phantom/importer.zig").imported;

pub const display = @import("phantom/display.zig");
pub const gpu = @import("phantom/gpu.zig");
pub const math = @import("phantom/math.zig");
pub const painting = @import("phantom/painting.zig");
pub const scene = @import("phantom/scene.zig");

pub const i18n = if (@hasDecl(imports, "i18n")) imports.i18n else @compileError("phantom.i18n module was not added to build.zig.zon");
