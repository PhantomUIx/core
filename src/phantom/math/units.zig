const vizops = @import("vizops");
const Node = @import("../scene/node.zig");

pub fn rel(frameInfo: Node.FrameInfo, value: vizops.vector.Float32Vector2) vizops.vector.UsizeVector2 {
    return value.mul(frameInfo.scale).mul(frameInfo.size.res.cast(f32)).div(100.0).cast(usize);
}

pub fn inches(frameInfo: Node.FrameInfo, value: vizops.vector.Float32Vector2) vizops.vector.UsizeVector2 {
    const physicalInches = frameInfo.size.phys.div(vizops.vector.Float32Vector2.init(25.4));
    const dpi = frameInfo.size.res.cast(f32).div(physicalInches).mul(frameInfo.scale);
    return dpi.mul(value).cast(usize);
}

pub fn cm(frameInfo: Node.FrameInfo, value: vizops.vector.Float32Vector2) vizops.vector.UsizeVector2 {
    const physicalCm = frameInfo.size.phys.div(vizops.vector.Float32Vector2.init(10.0));
    const dpcm = frameInfo.size.res.cast(f32).div(physicalCm).mul(frameInfo.scale);
    return dpcm.mul(value).cast(usize);
}

pub fn mm(frameInfo: Node.FrameInfo, value: vizops.vector.Float32Vector2) vizops.vector.UsizeVector2 {
    return frameInfo.size.res.cast(f32).div(frameInfo.size.phys).mul(frameInfo.scale).mul(value).cast(usize);
}
