pub const Opcode = enum(u8) { Return = 0, PushConstant, Negate, Add, Subtract, Multiply, Divide, Print, Pop, Plus, _ };

pub const SimpleInstruction = struct {};
pub const ConstantInstruction = struct { index: u8 };
pub const UnknownInstruction = struct { opcode: u8 };

pub const Instruction = union(enum) {
    Return: SimpleInstruction,
    PushConstant: ConstantInstruction,
    Unknown: UnknownInstruction,
    Negate: SimpleInstruction,
    Add: SimpleInstruction,
    Subtract: SimpleInstruction,
    Multiply: SimpleInstruction,
    Divide: SimpleInstruction,
    Print: SimpleInstruction,
    Pop: SimpleInstruction,
    Plus: SimpleInstruction,
};
