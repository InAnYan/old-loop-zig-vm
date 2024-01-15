const std = @import("std");
const memory_manager = @import("memory_manager.zig");
const MemoryManager = memory_manager.MemoryManager;
const MemoryManagerConfiguration = memory_manager.MemoryManagerConfiguration;
const Value = @import("value.zig").Value;
const Chunk = @import("chunk.zig").Chunk;
const instructions = @import("instructions.zig");
const Opcode = instructions.Opcode;
const Instruction = instructions.Instruction;
const RuntimeError = @import("errors.zig").RuntimeError;

pub const VirtualMachineConfiguration = struct {
    user_output: std.fs.File.Writer,
    debug_output: std.fs.File.Writer,
    trace_execution: bool,
    stack_size: usize,
};

pub const VirtualMachine = struct {
    conf: VirtualMachineConfiguration,
    memory_manager: MemoryManager,
    call_frames: std.ArrayList(CallFrame),
    stack: std.ArrayList(Value),

    const Self = @This();

    pub fn init(self: *Self, mem_conf: MemoryManagerConfiguration, vm_conf: VirtualMachineConfiguration) !void {
        self.conf = vm_conf;
        self.memory_manager = MemoryManager.init(mem_conf, self);
        const allocator = self.memory_manager.allocator();

        self.call_frames = std.ArrayList(CallFrame).init(allocator);
        self.stack = std.ArrayList(Value).init(allocator);
        try self.stack.ensureTotalCapacity(self.conf.stack_size);
    }

    pub fn deinit(self: *Self) void {
        self.memory_manager.deinit();
        self.call_frames.deinit();
        self.stack.deinit();
    }

    pub fn getAllocator(self: *VirtualMachine) std.mem.Allocator {
        return self.memory_manager.allocator();
    }

    pub fn run(self: *Self, chunk: *Chunk) !void {
        try self.call_frames.append(.{ .chunk = chunk, .ip = 0 });
        try self.runCycles();
    }

    fn runCycles(self: *Self) !void {
        while (true) {
            var frame = &self.call_frames.items[self.call_frames.items.len - 1];

            if (self.conf.trace_execution) {
                try self.traceStack();
                // NOTE: VM does not expect that the chunk could be empty.
                _ = try frame.chunk.disassembleInstruction(self.conf.debug_output, frame.ip);
            }

            const inst = try frame.readInstruction();
            switch (inst) {
                .Return => {
                    break;
                },

                .PushConstant => {
                    const constant = try frame.chunk.getConstant(inst.PushConstant.index);
                    try self.stackPush(constant);
                },

                .Negate => {
                    const value = try self.stackPop();
                    switch (value) {
                        .integer => {
                            try self.stackPush(Value{ .integer = -value.integer });
                        },
                    }
                },

                .Print => {
                    const value = try self.stackPop();
                    try value.print(self.conf.user_output);
                },

                .Add => {
                    try self.binaryOperation(BinaryOperation.Add);
                },

                .Subtract => {
                    try self.binaryOperation(BinaryOperation.Subtract);
                },

                .Multiply => {
                    try self.binaryOperation(BinaryOperation.Multiply);
                },

                .Divide => {
                    try self.binaryOperation(BinaryOperation.Divide);
                },

                .Pop => {
                    _ = try self.stackPop();
                },

                .Plus => {},

                .Unknown => {
                    try std.io.getStdErr().writer().print("Runtime error: unknown opcode 0x{x}.\n", .{inst.Unknown.opcode});
                    return RuntimeError.UnknownOpcode;
                },
            }
        }
    }

    const BinaryOperation = enum {
        Add,
        Subtract,
        Multiply,
        Divide,
    };

    fn binaryOperation(self: *Self, op: BinaryOperation) !void {
        const b = try self.stackPop();
        const a = try self.stackPop();

        if (a != .integer) {
            try std.io.getStdErr().writer().print("Runtime error: wrong type, expected integer, got {s}.\n", .{@tagName(a)});
        }

        if (b != .integer) {
            try std.io.getStdErr().writer().print("Runtime error: wrong type, expected integer, got {s}.\n", .{@tagName(b)});
        }

        var c: isize = undefined;
        switch (op) {
            .Add => {
                c = a.integer + b.integer;
            },

            .Subtract => {
                c = a.integer - b.integer;
            },

            .Multiply => {
                c = a.integer * b.integer;
            },

            .Divide => {
                if (b.integer == 0) {
                    return RuntimeError.ZeroDivision;
                }

                c = @divTrunc(a.integer, b.integer);
            },
        }

        try self.stackPush(.{ .integer = c });
    }

    fn stackPush(self: *Self, value: Value) !void {
        if (self.stack.items.len > self.conf.stack_size) {
            return RuntimeError.StackOverflow;
        }

        try self.stack.append(value);
    }

    fn stackPop(self: *Self) !Value {
        if (self.stack.items.len == 0) {
            return RuntimeError.StackUnderflow;
        }

        return self.stack.pop();
    }

    fn traceStack(self: *const Self) !void {
        var out = self.conf.debug_output;

        try out.writeAll("    ");

        for (self.stack.items) |value| {
            try out.writeAll("[ ");
            try value.print(out);
            try out.writeAll(" ]");
        }

        try out.writeAll("\n");
    }
};

pub const CallFrame = struct {
    chunk: *const Chunk,
    ip: usize,

    const Self = @This();

    pub fn readInstruction(self: *Self) !Instruction {
        const read_res = try self.chunk.readAt(self.ip);
        self.ip = read_res.offset;
        return read_res.inst;
    }
};
