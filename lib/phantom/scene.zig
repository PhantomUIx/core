//! Scene based rendering API

pub const Properties = @import("scene/Properties.zig");
pub const Renderer = @import("scene/Renderer.zig");
pub const Path = @import("scene/Path.zig");

pub const Node = union(enum) {
    container: Container,
    image: Image,
    text: Text,

    pub const Container = @import("scene/Node/Container.zig");
    pub const Image = @import("scene/Node/Image.zig");
    pub const Text = @import("scene/Node/Text.zig");

    pub fn getChildren(self: Node) []const Node {
        return switch (self) {
            .container => |container| container.children,
            else => &.{},
        };
    }

    test {
        _ = Container;
        _ = Image;
        _ = Text;
    }
};

test {
    _ = Properties;
    _ = Renderer;
    _ = Node;
    _ = Path;
}
