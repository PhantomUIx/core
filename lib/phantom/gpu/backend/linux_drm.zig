//! GPU backend for Linux using the Direct Rendering Manager subsystem.

pub const Connector = @import("linux_drm/Connector.zig");
pub const Device = @import("linux_drm/Device.zig");
pub const Provider = @import("linux_drm/Provider.zig");

test {
    _ = Connector;
    _ = Device;
    _ = Provider;
}
