const Scene = @import("../../base.zig");
const Node = @import("../../node.zig");
const HeadlessScene = @This();

pub const Options = struct {
    frame_info: Node.FrameInfo,
};

frame_info: Node.FrameInfo,

pub fn init(options: Options) HeadlessScene {
    return .{
        .frame_info = options.frame_info,
    };
}

pub fn scene(self: *HeadlessScene) Scene {
    return .{
        .ptr = self,
        .vtable = &.{
            .sub = null,
            .frameInfo = frameInfo,
        },
        .subscene = null,
    };
}

fn frameInfo(ctx: *anyopaque) Node.FrameInfo {
    const self: *HeadlessScene = @ptrCast(@alignCast(ctx));
    return self.frame_info;
}
