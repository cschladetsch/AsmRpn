#!/bin/bash

# Build the RPN calculator
echo "Assembling rpn.asm..."
nasm -f elf64 rpn.asm -o rpn.o

if [ $? -ne 0 ]; then
    echo "Assembly failed."
    exit 1
fi

echo "Linking rpn.o..."
ld rpn.o -o rpn

if [ $? -ne 0 ]; then
    echo "Linking failed."
    exit 1
fi

echo "Build successful. Running the program..."
echo "Press Ctrl+D to exit."
./rpn