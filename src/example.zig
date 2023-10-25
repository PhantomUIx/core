const std = @import("std");
const phantom = @import("phantom");

fn printDecl(comptime T: type) void {
    inline for (@typeInfo(T).Struct.decls) |decl| {
        const field = @field(T, decl.name);
        const fieldInfo = @typeInfo(@TypeOf(field));

        switch (fieldInfo) {
            .Fn => std.debug.print("{s}\n", .{decl.name}),
            .Struct => {
                std.debug.print("{}\n", .{field});
                printDecl(field);
            },
            else => std.debug.print("{}\n", .{field}),
        }
    }
}

pub fn main() void {
    printDecl(phantom);
}
