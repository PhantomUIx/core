const std = @import("std");
const Allocator = std.mem.Allocator;
const Widget = @import("Widget.zig");
const StateContext = @import("StateContext.zig");
const Self = @This();

pub const Payload = union(enum) {
    root: Root,
    child: Child,

    pub const Root = struct {
        pub const ContextMap = std.AutoHashMapUnmanaged(usize, *Self);
        pub const RebuildQueue = std.PriorityQueue(usize, *Root, compare);

        state_context: StateContext,
        context_map: ContextMap,
        next_id: usize = 0,
        rebuild_queue: RebuildQueue,

        pub fn destroy(self: *Root, alloc: Allocator) void {
            var iter = self.context_map.valueIterator();
            while (iter.next()) |ctx| {
                ctx.*.destroy();
            }

            self.context_map.deinit(alloc);
            self.state_context.destroy();
            self.rebuild_queue.deinit();
        }

        fn compare(self: *Root, a: usize, b: usize) std.math.Order {
            _ = self;
            // TODO: check how a or b depends on each other
            return std.math.order(a, b);
        }
    };

    pub const Child = struct {
        id: usize,
        widget: *const Widget,
    };

    pub fn destroy(self: *Payload, alloc: Allocator) void {
        return switch (self.*) {
            .root => |*root| root.destroy(alloc),
            .child => {},
        };
    }
};

pub const AncestorIterator = struct {
    value: ?*Self,

    pub fn next(self: *AncestorIterator) ?*Self {
        const v = self.value orelse return null;
        self.value = v.parent;
        return v;
    }
};

pub const ChildIterator = struct {
    root: *Payload.Root,
    parent: *Self,
    cmap_iter: Payload.Root.ContextMap.ValueIterator,

    pub fn next(self: *ChildIterator) ?*Self {
        while (self.cmap_iter.next()) |ctx| {
            if (ctx.parent == self.parent) return ctx;
        }
        return null;
    }
};

allocator: Allocator,
parent: ?*Self,
payload: Payload,

pub fn create(alloc: Allocator) !*Self {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .parent = null,
        .payload = .{
            .root = .{
                .state_context = .{
                    .allocator = alloc,
                },
                .rebuild_queue = Payload.Root.RebuildQueue.init(alloc, undefined),
                .context_map = .{},
                .next_id = 0,
            }
        },
    };
    self.payload.root.rebuild_queue.context = &self.payload.root;
    return self;
}

pub fn inner(self: *Self, widget: *const Widget) !*Self {
    const root = self.getRoot();

    var iter = root.context_map.iterator();
    while (iter.next()) |entry| {
        if (entry.value_ptr.*.payload.child.widget == widget) return entry.value_ptr.*;
    }

    const id = root.next_id;
    errdefer root.next_id = id;
    root.next_id += 1;

    const child = try self.allocator.create(Self);
    errdefer self.allocator.destroy(child);

    child.* = .{
        .allocator = self.allocator,
        .parent = self,
        .payload = .{
            .child = .{
                .id = id,
                .widget = widget,
            },
        },
    };

    try root.context_map.put(self.allocator, id, child);
    return child;
}

pub fn destroy(self: *Self) void {
    if (self.payload == .child) {
        const root = self.getRoot();
        _ = root.context_map.remove(self.payload.child.id);
    }

    self.payload.destroy(self.allocator);
    self.allocator.destroy(self);
}

pub fn useState(self: *Self, comptime T: type, init: T, disposeFn: StateContext.DisposeFn) !*T {
    const root = self.getRoot();
    return try root.state_context.getState(T, self.payload.child.id, init, disposeFn);
}

pub fn markDirty(self: *Self) void {
    const root = self.getRoot();
    return try root.rebuild_queue.add(self.payload.child.id);
}

pub fn needsRebuild(self: *Self) bool {
    const root = self.getRoot();

    var iter = root.rebuild_queue.iterator();
    while (iter.next()) |id| {
        if (id == self.payload.child.id) return true;
    }

    return self.payload.child.widget.needsRebuild(self);
}

/// Wrapper around `findAncestorWidgetOfTag` which uses the type name.
pub fn findAncestorWidgetOfType(self: *Self, comptime T: type) ?*T {
    if (self.findAncestorWidgetOfTag(@typeName(T))) |widget| {
        return @alignCast(@ptrCast(widget.ptr));
    }
    return null;
}

/// Finds an ancestor to the current build context with a tag that matches 
pub fn findAncestorWidgetOfTag(self: *Self, tag: []const u8) ?*const Widget {
    var iter = self.ancestorIterator();
    while (iter.next()) |ctx| {
        if (std.mem.eql(u8, ctx.payload.child.widget.tag, tag)) {
            return ctx.payload.child.widget;
        }
    }
    return null;
}

pub fn ancestorIterator(self: *Self) AncestorIterator {
    return .{
        .value = self.parent,
    };
}

pub fn childIterator(self: *Self) ChildIterator {
    const root = self.getRoot();
    return .{
        .root = root,
        .parent = self,
        .cmap_iter = root.context_map.valueIterator(),
    };
}

fn getRoot(self: *Self) *Payload.Root {
    if (self.payload == .root) {
        return &self.payload.root;
    }

    var iter = self.ancestorIterator();
    while (iter.next()) |ctx| {
        if (ctx.payload == .root) {
            return &ctx.payload.root;
        }
    }

    return undefined;
}
