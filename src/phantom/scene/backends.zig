const root = @import("root");

pub const headless = @import("backends/headless.zig");
pub usingnamespace if (@hasDecl(root, "phantom")) if (@hasDecl(root.phantom, "backends")) root.phantom.backends else struct {} else struct {};
