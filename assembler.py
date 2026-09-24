import argparse
import re
import tempfile
from dataclasses import dataclass
from enum import Enum
from pathlib import Path


MAX_PROGRAM_INSTRUCTIONS = 512
MAX_IMMEDIATE = 0xFF
MAX_ADDRESS = 0x7FF


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

    def encode(self, operands: list[int]) -> int:
        if len(operands) != len(self.operands):
            raise ValueError(
                f"opcode {self.opcode:#07b} expects {len(self.operands)} operands, "
                f"found {len(operands)}"
            )

        encoded_instruction = self.opcode << 11
        for operand in self.operands:
            value = operands[operand.order_position]
            if operand.type in (OperandType.REGISTER, OperandType.VECTOR_REGISTER):
                max_value = 0b111
            elif operand.type == OperandType.IMMEDIATE:
                max_value = MAX_IMMEDIATE
            else:
                max_value = MAX_ADDRESS

            if not 0 <= value <= max_value:
                raise ValueError(f"operand value {value} does not fit its instruction field")
            encoded_instruction |= value << operand.bit_offset

        if not 0 <= encoded_instruction <= 0xFFFF:
            raise ValueError(f"encoded instruction {encoded_instruction} does not fit in 16 bits")
        return encoded_instruction


class Assembler:
    def __init__(self):
        scalar = OperandType.REGISTER
        vector = OperandType.VECTOR_REGISTER

        def descriptor(opcode: int, *operand_types: OperandType) -> InstructionDescriptor:
            offsets_by_count = {
                0: (),
                1: (8,),
                2: (8, 5),
                3: (8, 5, 2),
            }
            offsets = offsets_by_count[len(operand_types)]
            return InstructionDescriptor(
                opcode=opcode,
                operands=[
                    Operand(order_position=index, bit_offset=offset, type=operand_type)
                    for index, (offset, operand_type) in enumerate(zip(offsets, operand_types))
                ],
            )

        def immediate_descriptor(opcode: int) -> InstructionDescriptor:
            return InstructionDescriptor(
                opcode=opcode,
                operands=[
                    Operand(0, 8, scalar),
                    Operand(1, 0, OperandType.IMMEDIATE),
                ],
            )

        def jump_descriptor(opcode: int) -> InstructionDescriptor:
            return InstructionDescriptor(
                opcode=opcode,
                operands=[Operand(0, 0, OperandType.ADDRESS)],
            )

        self.instruction_descriptors: dict[str, InstructionDescriptor] = {
            "ldi": immediate_descriptor(0x00),
            "mov": descriptor(0x01, scalar, scalar),
            "add": descriptor(0x02, scalar, scalar, scalar),
            "sub": descriptor(0x03, scalar, scalar, scalar),
            "and": descriptor(0x04, scalar, scalar, scalar),
            "or": descriptor(0x05, scalar, scalar, scalar),
            "xor": descriptor(0x06, scalar, scalar, scalar),
            "shl": descriptor(0x07, scalar, scalar, scalar),
            "shr": descriptor(0x08, scalar, scalar, scalar),
            "mul": descriptor(0x09, scalar, scalar, scalar),
            "load": descriptor(0x0A, scalar, scalar),
            "store": descriptor(0x0B, scalar, scalar),
            "cmp": descriptor(0x0C, scalar, scalar),
            "jmp": jump_descriptor(0x0D),
            "jz": jump_descriptor(0x0E),
            "jlt": jump_descriptor(0x1A),
            "halt": descriptor(0x0F),
            "vld": descriptor(0x10, vector, scalar),
            "vst": descriptor(0x11, scalar, vector),
            "vadd": descriptor(0x12, vector, vector, vector),
            "vsub": descriptor(0x13, vector, vector, vector),
            "vmul": descriptor(0x14, vector, vector, vector),
            "vdot": descriptor(0x15, scalar, vector, vector),
            "lui": immediate_descriptor(0x16),
            "tid": descriptor(0x17, scalar),
            "glaunch": jump_descriptor(0x18),
            "gwait": jump_descriptor(0x19),
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
                f"line {line_num}: {mnemonic} expects {expected_operand_count} operands, "
                f"found {len(operands)}"
            )

        parsed_operands = []
        for operand, token in zip(descriptor.operands, operands):
            if operand.type in (OperandType.REGISTER, OperandType.VECTOR_REGISTER):
                register_prefix = "r" if operand.type == OperandType.REGISTER else "v"
                register_kind = (
                    "register" if operand.type == OperandType.REGISTER else "vector register"
                )
                match = re.fullmatch(rf"{register_prefix}([1-8])", token, re.IGNORECASE)
                if not match:
                    raise Exception(
                        f"line {line_num}: {register_kind} {token} is outside the supported range "
                        f"{register_prefix}1-{register_prefix}8"
                    )
                parsed_operands.append(int(match.group(1)) - 1)
                continue

            if not re.fullmatch(r"[0-9]+", token):
                raise Exception(
                    f"line {line_num}: expected an unsigned decimal value, found '{token}'"
                )

            value = int(token)
            if operand.type == OperandType.IMMEDIATE:
                operand_name = "immediate"
                maximum = MAX_IMMEDIATE
            else:
                operand_name = "address"
                maximum = MAX_ADDRESS
            if value > maximum:
                raise Exception(
                    f"line {line_num}: {operand_name} {value} is outside the supported range "
                    f"0-{maximum}"
                )
            parsed_operands.append(value)

        return descriptor, parsed_operands

    def assemble_file(self, filename: str):
        with open(filename) as source_file:
            with tempfile.NamedTemporaryFile(mode="w", delete=False) as target_file:
                temp_file_path = Path(target_file.name)
                instruction_count = 0
                for line_num, line in enumerate(source_file, start=1):
                    tokens = line.split("#", 1)[0].split()
                    if not tokens:
                        continue
                    mnemonic, *operands = tokens
                    if instruction_count >= MAX_PROGRAM_INSTRUCTIONS:
                        raise Exception(
                            f"line {line_num}: The program does not fit into the chip's memory. "
                            "The biggest supported program is 512 instructions"
                        )

                    instruction, parsed_operands = self.validate(
                        line_num, mnemonic, operands
                    )
                    target_file.write(f"{instruction.encode(parsed_operands):04X}\n")
                    instruction_count += 1
        temp_file_path.replace("./program.hex")


if __name__ == "__main__":
    argparser = argparse.ArgumentParser(
        prog="Assembler",
        description="The assembler for the CPU in this project. For ISA details see README.md",
    )
    argparser.add_argument("filename")
    args = argparser.parse_args()
    Assembler().assemble_file(args.filename)
