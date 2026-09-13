import argparse
import re
import tempfile
from dataclasses import dataclass
from enum import Enum
from pathlib import Path


MAX_PROGRAM_INSTRUCTIONS = 512
MAX_NINE_BIT_VALUE = 0x1FF
MEMORY_VECTOR_FLAG_BIT = 5
MEMORY_VECTOR_FLAG = 1 << MEMORY_VECTOR_FLAG_BIT
HALT_OR_VECTOR_SUBOP_HALT = 0b000
HALT_OR_VECTOR_SUBOP_VADD = 0b001
HALT_OR_VECTOR_SUBOP_VSUB = 0b010
HALT_OR_VECTOR_SUBOP_VMUL = 0b011
HALT_OR_VECTOR_SUBOP_VDOT = 0b100


class OperandType(Enum):
    REGISTER = "REGISTER"
    VECTOR_REGISTER = "VECTOR_REGISTER"
    IMMEDIATE = "IMMEDIATE"
    ADDRESS = "ADDRESS"


@dataclass
class Operand:
    order_position: int
    bit_offset: int
    type: OperandType


@dataclass
class InstructionDescriptor:
    opcode: int
    operands: list[Operand]
    fixed_bits: int = 0

    def encode(self, operands: list[int]) -> int:
        if len(operands) != len(self.operands):
            raise ValueError(
                f"opcode {self.opcode:#06b} expects {len(self.operands)} operands, "
                f"found {len(operands)}"
            )

        encoded_instruction = (self.opcode << 12) | self.fixed_bits

        for operand in self.operands:
            value = operands[operand.order_position]
            max_value = (
                0b111
                if operand.type in (OperandType.REGISTER, OperandType.VECTOR_REGISTER)
                else MAX_NINE_BIT_VALUE
            )
            if not 0 <= value <= max_value:
                raise ValueError(f"operand value {value} does not fit its instruction field")
            encoded_instruction |= (
                value << operand.bit_offset
            )

        if not 0 <= encoded_instruction <= 0xFFFF:
            raise ValueError(f"encoded instruction {encoded_instruction} does not fit in 16 bits")

        return encoded_instruction


class Assembler:
    def __init__(self):
        self.instruction_descriptors: dict[str, InstructionDescriptor] = {
            "ldi": InstructionDescriptor(
                opcode=0b0000,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=0,
                        type=OperandType.IMMEDIATE,
                    ),
                ],
            ),
            "mov": InstructionDescriptor(
                opcode=0b0001,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "add": InstructionDescriptor(
                opcode=0b0010,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=3,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "sub": InstructionDescriptor(
                opcode=0b0011,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=3,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "and": InstructionDescriptor(
                opcode=0b0100,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=3,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "or": InstructionDescriptor(
                opcode=0b0101,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=3,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "xor": InstructionDescriptor(
                opcode=0b0110,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=3,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "shl": InstructionDescriptor(
                opcode=0b0111,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=3,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "shr": InstructionDescriptor(
                opcode=0b1000,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=3,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "mul": InstructionDescriptor(
                opcode=0b1001,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=3,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "load": InstructionDescriptor(
                opcode=0b1010,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "store": InstructionDescriptor(
                opcode=0b1011,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "vload": InstructionDescriptor(
                opcode=0b1010,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                ],
                fixed_bits=MEMORY_VECTOR_FLAG,
            ),
            "vstore": InstructionDescriptor(
                opcode=0b1011,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                ],
                fixed_bits=MEMORY_VECTOR_FLAG,
            ),
            "vadd": InstructionDescriptor(
                opcode=0b1111,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=6,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=3,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=0,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                ],
                fixed_bits=HALT_OR_VECTOR_SUBOP_VADD << 9,
            ),
            "vsub": InstructionDescriptor(
                opcode=0b1111,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=6,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=3,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=0,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                ],
                fixed_bits=HALT_OR_VECTOR_SUBOP_VSUB << 9,
            ),
            "vmul": InstructionDescriptor(
                opcode=0b1111,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=6,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=3,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=0,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                ],
                fixed_bits=HALT_OR_VECTOR_SUBOP_VMUL << 9,
            ),
            "vdot": InstructionDescriptor(
                opcode=0b1111,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=6,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=3,
                        type=OperandType.VECTOR_REGISTER,
                    ),
                    Operand(
                        order_position=2,
                        bit_offset=0,
                        type=OperandType.REGISTER,
                    ),
                ],
                fixed_bits=HALT_OR_VECTOR_SUBOP_VDOT << 9,
            ),
            "cmp": InstructionDescriptor(
                opcode=0b1100,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=9,
                        type=OperandType.REGISTER,
                    ),
                    Operand(
                        order_position=1,
                        bit_offset=6,
                        type=OperandType.REGISTER,
                    ),
                ],
            ),
            "jmp": InstructionDescriptor(
                opcode=0b1101,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=0,
                        type=OperandType.ADDRESS,
                    )
                ],
            ),
            "je": InstructionDescriptor(
                opcode=0b1110,
                operands=[
                    Operand(
                        order_position=0,
                        bit_offset=0,
                        type=OperandType.ADDRESS,
                    )
                ],
            ),
            "halt_or_vector": InstructionDescriptor(
                opcode=0b1111,
                operands=[],
            ),
        }

    def validate(
        self, line_num: int, mnemonic: str, operands: list[str]
    ) -> tuple[InstructionDescriptor, list[int]]:
        descriptor = self.instruction_descriptors.get(mnemonic.lower())
        if not descriptor:
            raise Exception(f"line {line_num}: unknown instruction '{mnemonic}'")

        expected_operand_count = len(descriptor.operands)
        if expected_operand_count != len(operands):
            raise Exception(
                f"line {line_num}: {mnemonic} expects {expected_operand_count} operands, found {len(operands)}"
            )

        parsed_operands = []
        for operand, token in zip(descriptor.operands, operands):
            if operand.type in (OperandType.REGISTER, OperandType.VECTOR_REGISTER):
                register_prefix = "r" if operand.type == OperandType.REGISTER else "v"
                register_kind = "register" if operand.type == OperandType.REGISTER else "vector register"
                match = re.fullmatch(rf"{register_prefix}([1-8])", token, re.IGNORECASE)
                if not match:
                    raise Exception(
                        f"line {line_num}: {register_kind} {token} is outside the supported range "
                        f"{register_prefix}1-{register_prefix}8"
                    )

                # The source names are one-based, while the 3-bit register fields are zero-based.
                parsed_operands.append(int(match.group(1)) - 1)
                continue

            if not re.fullmatch(r"[0-9]+", token):
                raise Exception(
                    f"line {line_num}: expected an unsigned decimal value, found '{token}'"
                )

            value = int(token)
            operand_name = (
                "immediate" if operand.type == OperandType.IMMEDIATE else "address"
            )
            if value > MAX_NINE_BIT_VALUE:
                raise Exception(
                    f"line {line_num}: {operand_name} {value} is outside the supported range 0-511"
                )
            parsed_operands.append(value)

        return descriptor, parsed_operands

    def assemble_file(self, filename: str):
        with open(filename) as f:
            with tempfile.NamedTemporaryFile(mode="w", delete=False) as target_file:
                temp_file_path = Path(target_file.name)
                instruction_count = 0
                for line_num, line in enumerate(f, start=1):
                    tokens = line.split("#", 1)[0].split()
                    if not tokens:
                        continue
                    mnemonic, *operands = tokens
                    if instruction_count >= MAX_PROGRAM_INSTRUCTIONS:
                        raise Exception(
                            f"line {line_num}: The program does not fit into the chip's memory. "
                            "The biggest supported program is 512 instructions"
                        )

                    descriptor, parsed_operands = self.validate(
                        line_num, mnemonic, operands
                    )
                    word = descriptor.encode(parsed_operands)
                    target_file.write(f"{word:04X}\n")
                    instruction_count += 1
        temp_file_path.replace("./program.hex")


if __name__ == "__main__":
    argparser = argparse.ArgumentParser(
        prog="Assembler",
        description="The assembler for the CPU in this project. For detail on the ISA look at the README.md",
    )

    argparser.add_argument("filename")

    args = argparser.parse_args()
    Assembler().assemble_file(args.filename)
