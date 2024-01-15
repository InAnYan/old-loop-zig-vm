const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const virtual_machine = @import("virtual_machine.zig");
const VirtualMachine = virtual_machine.VirtualMachine;
const VirtualMachineConfiguration = virtual_machine.VirtualMachineConfiguration;
const MemoryManagerConfiguration = @import("memory_manager.zig").MemoryManagerConfiguration;
const Value = @import("value.zig").Value;
const Instruction = @import("instructions.zig").Instruction;
const RuntimeError = @import("errors.zig").RuntimeError;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Memory leak detected");
    }

    var allocator = gpa.allocator();

    const mem_conf = MemoryManagerConfiguration{ .parent_allocator = allocator };
    const vm_conf = VirtualMachineConfiguration{
        .user_output = std.io.getStdOut().writer(),
        .debug_output = std.io.getStdErr().writer(),
        .trace_execution = true,
        .stack_size = 256,
    };

    var vm: *VirtualMachine = try allocator.create(VirtualMachine);
    defer allocator.destroy(vm);

    try vm.init(mem_conf, vm_conf);
    defer vm.deinit();

    const args = try std.process.argsAlloc(vm.getAllocator());
    defer std.process.argsFree(vm.getAllocator(), args);

    if (args.len != 2) {
        try std.io.getStdErr().writeAll("error: wrong arguments count (expected path to chunk)\n");
        return RuntimeError.WrongArgumentsCount;
    }

    const path = args[1];
    const file = try std.fs.cwd().openFile(
        path,
        .{},
    );
    defer file.close();

    const buf = try file.readToEndAlloc(vm.getAllocator(), 1024);
    defer vm.getAllocator().free(buf);

    var chunk = try Chunk.fromBuffer(vm, buf);
    defer chunk.deinit();

    try chunk.disassemble(std.io.getStdOut().writer(), "test chunk");

    try vm.run(&chunk);
}
