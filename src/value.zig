const std = @import("std");
const RuntimeError = @import("errors.zig").RuntimeError;

pub const Value = union(enum) {
    integer: isize,

    const Self = @This();

    pub fn fromJSON(value: std.json.Value) !Self {
        const t = value.object.get("type").?.string;
        if (std.mem.eql(u8, t, "integer")) {
            const n = value.object.get("data").?.integer;
            return Self{ .integer = n };
        } else {
            return RuntimeError.WrongJSON;
        }
    }

    pub fn print(self: *const Self, writer: anytype) !void {
        switch (self.*) {
            .integer => |n| try writer.print("{d}", .{n}),
        }
    }
};
