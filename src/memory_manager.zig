const std = @import("std");
const Allocator = std.mem.Allocator;
const VirtualMachine = @import("virtual_machine.zig").VirtualMachine;

pub const MemoryManagerConfiguration = struct {
    parent_allocator: Allocator,
};

pub const MemoryManager = struct {
    conf: MemoryManagerConfiguration,
    vm: *VirtualMachine,

    const Self = @This();

    pub fn init(conf: MemoryManagerConfiguration, vm: *VirtualMachine) Self {
        return .{ .conf = conf, .vm = vm };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn allocator(self: *Self) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        log2_ptr_align: u8,
        ra: usize,
    ) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.conf.parent_allocator.rawAlloc(len, log2_ptr_align, ra);
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        new_len: usize,
        ra: usize,
    ) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.conf.parent_allocator.rawResize(buf, log2_buf_align, new_len, ra);
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        ra: usize,
    ) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.conf.parent_allocator.rawFree(buf, log2_buf_align, ra);
    }
};
