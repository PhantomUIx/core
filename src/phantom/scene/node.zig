const std = @import("std");
const builtin = @import("builtin");
const anyplus = @import("any+");
const vizops = @import("vizops");
const Scene = @import("base.zig");
const Node = @This();

pub const FrameInfo = struct {
    size: struct {
        phys: vizops.vector.Float32Vector2,
        res: vizops.vector.UsizeVector2,
        avail: vizops.vector.UsizeVector2,
    },
    scale: vizops.vector.Float32Vector2,
    colorFormat: vizops.color.fourcc.Value,
    seq: u64 = 0,

    pub const Options = struct {
        res: vizops.vector.UsizeVector2,
        scale: vizops.vector.Float32Vector2 = vizops.vector.Float32Vector2.init(1.0),
        physicalSize: vizops.vector.Float32Vector2 = vizops.vector.Float32Vector2.zero(),
        colorFormat: vizops.color.fourcc.Value,
    };

    pub fn init(options: Options) FrameInfo {
        return .{
            .size = .{
                .phys = options.physicalSize,
                .res = options.res,
                .avail = options.res,
            },
            .scale = options.scale,
            .colorFormat = options.colorFormat,
        };
    }

    pub fn equal(self: FrameInfo, other: FrameInfo) bool {
        return std.simd.countTrues(@Vector(5, bool){
            self.size.phys.eq(other.size.phys),
            self.size.res.eq(other.size.res),
            self.size.avail.eq(other.size.avail),
            self.scale.eq(other.scale),
            self.colorFormat.eq(other.colorFormat),
        }) == 5;
    }

    pub fn withSequence(self: FrameInfo, value: u64) FrameInfo {
        return .{
            .size = self.size,
            .scale = self.scale,
            .colorFormat = self.colorFormat,
            .seq = value,
        };
    }

    pub fn child(self: FrameInfo, availSize: vizops.vector.UsizeVector2) FrameInfo {
        return .{ .size = .{
            .phys = self.size.phys,
            .res = self.size.res,
            .avail = availSize,
        }, .scale = self.scale, .colorFormat = self.colorFormat, .seq = self.seq };
    }
};

pub const VTable = struct {
    dupe: *const fn (*anyopaque) anyerror!*Node,
    state: *const fn (*anyopaque, FrameInfo) anyerror!State,
    preFrame: *const fn (*anyopaque, FrameInfo, *Scene) anyerror!State,
    frame: *const fn (*anyopaque, *Scene) anyerror!void,
    postFrame: ?*const fn (*anyopaque, *Scene) anyerror!void = null,
    deinit: ?*const fn (*anyopaque) void = null,
    format: ?*const fn (*anyopaque, ?std.mem.Allocator) anyerror!std.ArrayList(u8) = null,
    cast: ?*const fn (*anyopaque, []const u8) error{BadCast}!*anyopaque = null,
    setProperties: ?*const fn (*anyopaque, std.StringHashMap(anyplus.Anytype)) anyerror!void = null,
};

pub const State = struct {
    size: vizops.vector.UsizeVector2,
    frame_info: FrameInfo,
    ptr: ?*anyopaque = null,
    allocator: ?std.mem.Allocator = null,
    ptrEqual: ?*const fn (*anyopaque, *anyopaque) bool = null,
    ptrFree: ?*const fn (*anyopaque, std.mem.Allocator) void = null,
    type: []const u8,

    pub inline fn deinit(self: State, alloc: ?std.mem.Allocator) void {
        return if (self.ptrFree) |f| f(self.ptr.?, (self.allocator orelse alloc).?);
    }

    pub fn equal(self: State, other: State) bool {
        const typeMatch = std.mem.eql(u8, self.type, other.type);
        return std.simd.countTrues(@Vector(4, bool){
            self.size.eq(other.size),
            self.frame_info.equal(other.frame_info),
            if (typeMatch) if (self.ptrEqual) |f| f(self.ptr.?, other.ptr.?) else self.ptr == other.ptr else false,
            typeMatch,
        }) == 4;
    }
};

allocator: std.mem.Allocator,
vtable: *const VTable,
ptr: *anyopaque,
type: []const u8,
id: usize,
last_state: ?State = null,

pub inline fn dupe(self: *Node) anyerror!*Node {
    return self.vtable.dupe(self.ptr);
}

pub inline fn state(self: *Node, frameInfo: FrameInfo) anyerror!State {
    return self.vtable.state(self.ptr, frameInfo);
}

pub fn preFrame(self: *Node, frameInfo: FrameInfo, scene: *Scene) anyerror!bool {
    const newState = try self.vtable.preFrame(self.ptr, frameInfo, scene);
    const shouldApply = !(if (self.last_state) |lastState| lastState.equal(newState) else false);

    if (shouldApply) {
        if (self.last_state) |l| l.deinit(self.allocator);

        self.last_state = newState;
    } else {
        newState.deinit(self.allocator);
    }
    return shouldApply;
}

pub inline fn frame(self: *Node, scene: *Scene) anyerror!void {
    return if (self.last_state != null) self.vtable.frame(self.ptr, scene);
}

pub inline fn postFrame(self: *Node, scene: *Scene) anyerror!void {
    return if (self.last_state != null) (if (self.vtable.postFrame) |f| f(self.ptr, scene));
}

pub inline fn deinit(self: *Node) void {
    if (self.last_state) |l| l.deinit(self.allocator);
    if (self.vtable.deinit) |f| f(self.ptr);
}

pub fn format(self: *const Node, comptime _: []const u8, options: std.fmt.FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
    _ = options;

    if (self.vtable.format) |fmt| {
        const output = fmt(self.ptr, if (self.last_state) |s| s.allocator else null) catch return error.OutOfMemory;
        defer output.deinit();

        self.formatName(output.allocator, writer) catch return error.OutOfMemory;
        try writer.writeByte(' ');
        try writer.writeAll(output.items);
    } else {
        self.formatName(if (self.last_state) |s| s.allocator else null, writer) catch return error.OutOfMemory;
        try writer.print(" {{ .last_state = {?} }}", .{self.last_state});
    }
}

pub fn formatName(self: *const Node, optAlloc: ?std.mem.Allocator, writer: anytype) !void {
    if (builtin.mode == .Debug and !builtin.strip_debug_info and @hasDecl(std.posix, "errno") and @hasDecl(std.posix.system, "fd_t")) {
        const alloc = optAlloc orelse self.allocator;
        const debug = try std.debug.getSelfDebugInfo();
        const mod = try debug.getModuleForAddress(self.id);
        const sym = try mod.getSymbolAtAddress(alloc, self.id);
        defer sym.deinit(alloc);

        try std.fmt.format(writer, "{s}@", .{self.type});

        if (sym.line_info) |line| {
            try std.fmt.format(writer, "{s}:{}:{}", .{ line.file_name, line.line, line.column });
        } else {
            try std.fmt.format(writer, "{s}", .{sym.symbol_name});
        }
    } else if (builtin.mode == .ReleaseSmall) {
        return std.fmt.format(writer, "{s}@{x}", .{ self.type, @intFromPtr(self.ptr) });
    } else {
        return std.fmt.format(writer, "{s}@{x}", .{ self.type, self.id });
    }
}

pub fn cast(self: *Node, comptime T: type) error{BadCast}!*T {
    if (self.vtable.cast) |f| return f(self.ptr, @typeName(T));
    return error.BadCast;
}

pub fn setProperties(self: *Node, args: anytype) !void {
    if (self.vtable.setProperties) |f| {
        var argsMap = std.StringHashMap(anyplus.Anytype).init(self.allocator);
        defer argsMap.deinit();

        inline for (@typeInfo(@TypeOf(args)).Struct.fields) |fieldInfo| {
            const field = @field(args, fieldInfo.name);
            try argsMap.put(fieldInfo.name, anyplus.Anytype.init(field));
        }
        return f(self.ptr, argsMap);
    }
    return error.NoProperties;
}
