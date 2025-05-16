const builtin = @import("builtin");

pub const linux_drm = @import("backend/linux_drm.zig");

test {
    if (builtin.os.tag == .linux) {
        _ = linux_drm;
    }
}
