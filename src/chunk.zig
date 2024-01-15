const std = @import("std");
const VirtualMachine = @import("virtual_machine.zig").VirtualMachine;
const Opcode = @import("instructions.zig").Opcode;
const Value = @import("value.zig").Value;
const Instruction = @import("instructions.zig").Instruction;
const RuntimeError = @import("errors.zig").RuntimeError;

pub const Chunk = struct {
    code: std.ArrayList(u8),
    constants: std.ArrayList(Value),
    lines: std.ArrayList(usize),

    const Self = @This();

    pub fn init(vm: *VirtualMachine) Self {
        return .{ .code = std.ArrayList(u8).init(vm.getAllocator()), .constants = std.ArrayList(Value).init(vm.getAllocator()), .lines = std.ArrayList(usize).init(vm.getAllocator()) };
    }

    pub fn fromBuffer(vm: *VirtualMachine, buf: []const u8) !Self {
        const json = try std.json.parseFromSlice(std.json.Value, vm.getAllocator(), buf, .{});
        defer json.deinit();

        const object = json.value.object;

        var chunk = Self.init(vm);

        for (object.get("code").?.array.items) |elem| {
            try chunk.code.append(@intCast(elem.integer));
        }

        for (object.get("constants").?.array.items) |elem| {
            try chunk.constants.append(try Value.fromJSON(elem));
        }

        for (object.get("lines").?.array.items) |elem| {
            try chunk.lines.append(@intCast(elem.integer)); // NOTE: Potential bug because of @as.
        }

        return chunk;
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
        self.constants.deinit();
        self.lines.deinit();
    }

    pub const ReadResult = struct {
        inst: Instruction,
        offset: usize,
    };

    pub fn readAt(self: *const Self, offset: usize) !ReadResult {
        const opcode = try self.getOpcode(offset);
        switch (opcode) {
            .Return => {
                return .{ .inst = .{ .Return = .{} }, .offset = offset + 1 };
            },

            .PushConstant => {
                const index = try self.getByte(offset + 1);
                return .{ .inst = .{ .PushConstant = .{ .index = index } }, .offset = offset + 2 };
            },

            .Negate => {
                return .{ .inst = .{ .Negate = .{} }, .offset = offset + 1 };
            },

            .Add => {
                return .{ .inst = .{ .Add = .{} }, .offset = offset + 1 };
            },

            .Subtract => {
                return .{ .inst = .{ .Subtract = .{} }, .offset = offset + 1 };
            },

            .Multiply => {
                return .{ .inst = .{ .Multiply = .{} }, .offset = offset + 1 };
            },

            .Divide => {
                return .{ .inst = .{ .Divide = .{} }, .offset = offset + 1 };
            },

            .Print => {
                return .{ .inst = .{ .Print = .{} }, .offset = offset + 1 };
            },

            .Pop => {
                return .{ .inst = .{ .Pop = .{} }, .offset = offset + 1 };
            },

            .Plus => {
                return .{ .inst = .{ .Plus = .{} }, .offset = offset + 1 };
            },

            _ => {
                return .{ .inst = .{ .Unknown = .{ .opcode = @intFromEnum(opcode) } }, .offset = offset + 1 };
            },
        }
    }

    pub fn getByte(self: *const Self, offset: usize) !u8 {
        if (!self.isValidCodeOffset(offset)) {
            return RuntimeError.ReadingPastTheChunk;
        }

        return self.code.items[offset];
    }

    pub fn getOpcode(self: *const Self, offset: usize) !Opcode {
        return @enumFromInt(try self.getByte(offset));
    }

    pub fn getConstant(self: *const Self, index: u8) !Value {
        if (!self.isValidConstantIndex(index)) {
            return RuntimeError.ConstantDoesNotExists;
        }

        return self.constants.items[index];
    }

    pub fn isValidCodeOffset(self: *const Self, offset: usize) bool {
        return offset < self.code.items.len;
    }

    pub fn isValidConstantIndex(self: *const Self, index: u8) bool {
        return index < self.constants.items.len;
    }

    pub fn disassemble(self: *const Self, writer: anytype, name: []const u8) !void {
        try writer.print("== {s} ==\n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            offset = try self.disassembleInstruction(writer, offset);
        }
    }

    pub fn disassembleInstruction(self: *const Self, writer: anytype, offset: usize) !usize {
        try writer.print("{d:0>4} ", .{offset});

        const byte = self.code.items[offset];
        const op: Opcode = @enumFromInt(byte);
        switch (op) {
            .Return => {
                return try self.simpleInstruction(writer, "ret", offset);
            },

            .PushConstant => {
                return try self.constantInstruction(writer, "push", offset);
            },

            .Negate => {
                return try self.simpleInstruction(writer, "neg", offset);
            },

            .Add => {
                return try self.simpleInstruction(writer, "add", offset);
            },

            .Subtract => {
                return try self.simpleInstruction(writer, "sub", offset);
            },

            .Multiply => {
                return try self.simpleInstruction(writer, "mul", offset);
            },

            .Divide => {
                return try self.simpleInstruction(writer, "div", offset);
            },

            .Print => {
                return try self.simpleInstruction(writer, "print", offset);
            },

            .Pop => {
                return try self.simpleInstruction(writer, "pop", offset);
            },

            .Plus => {
                return try self.simpleInstruction(writer, "plus", offset);
            },

            _ => {
                try writer.print("Unknown opcode 0x{x}.\n", .{byte});
                return offset + 1;
            },
        }
    }

    fn simpleInstruction(self: *const Self, writer: anytype, name: []const u8, offset: usize) !usize {
        _ = self;
        try writer.print("{s}\n", .{name});
        return offset + 1;
    }

    fn constantInstruction(self: *const Self, writer: anytype, name: []const u8, offset: usize) !usize {
        const index = self.code.items[offset + 1];
        const value = self.constants.items[index];

        try writer.print("{s:<16} {d:4} '", .{ name, index });
        try value.print(writer);
        try writer.print("'\n", .{});

        return offset + 2;
    }
};
