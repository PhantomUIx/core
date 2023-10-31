const vizops = @import("vizops");
const Node = @import("../scene/node.zig");
const UsizeVector = vizops.vector.Vector2(usize);

pub fn percentage(frameInfo: Node.FrameInfo, value: vizops.vector.Float32Vector2) UsizeVector {
    return UsizeVector.init(.{
        @intFromFloat(value.value[0] * frameInfo.scale.value[0] * @as(f32, @floatFromInt(frameInfo.size.res.value[0])) / 100.0),
        @intFromFloat(value.value[1] * frameInfo.scale.value[1] * @as(f32, @floatFromInt(frameInfo.size.res.value[1])) / 100.0),
    });
}

pub fn inches(frameInfo: Node.FrameInfo, value: vizops.vector.Float32Vector2) UsizeVector {
    const physicalInches = frameInfo.size.phys.div(vizops.vector.Float32Vector2.init(.{25.4} ** 2));
    const dpi = vizops.vector.Float32Vector2.init(.{
        @as(f32, @floatFromInt(frameInfo.size.res.value[0])) / physicalInches.value[0],
        @as(f32, @floatFromInt(frameInfo.size.res.value[1])) / physicalInches.value[1],
    }).mul(frameInfo.scale);
    return UsizeVector.init(.{
        @intFromFloat(dpi.value[0] * value.value[0]),
        @intFromFloat(dpi.value[1] * value.value[1]),
    });
}
