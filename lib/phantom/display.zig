pub const Client = @import("display/Client.zig");
pub const Input = @import("display/Input.zig");
pub const Output = @import("display/Output.zig");
pub const Provider = @import("display/Provider.zig");
pub const Server = @import("display/Server.zig");
pub const Surface = @import("display/Surface.zig");
pub const Subsurface = @import("display/Subsurface.zig");
pub const Toplevel = @import("display/Toplevel.zig");

test {
    _ = Client;
    _ = Input;
    _ = Output;
    _ = Provider;
    _ = Server;
    _ = Surface;
    _ = Subsurface;
    _ = Toplevel;
}
