import argparse

parser = argparse.ArgumentParser(
    prog="Assembler",
    description="The assembler for the CPU in this project. For detail on the ISA look at the README.md",
)

parser.add_argument("filename")

args = parser.parse_args()

with open(args.filename) as f:
    for line in f:
        print(line)
