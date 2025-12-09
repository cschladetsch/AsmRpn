#!/bin/bash

# Build the RPN calculator
echo "Assembling src/*.asm..."
nasm -f elf64 src/main.asm -g -o main.o
nasm -f elf64 src/executor.asm -g -o executor.o
nasm -f elf64 src/tokenizer.asm -g -o tokenizer.o
nasm -f elf64 src/parser.asm -g -o parser.o
nasm -f elf64 src/translator.asm -g -o translator.o

if [ $? -ne 0 ]; then
    echo "Assembly failed."
    exit 1
fi

echo "Linking *.o..."
ld main.o executor.o tokenizer.o parser.o translator.o -o rpn

if [ $? -ne 0 ]; then
    echo "Linking failed."
    exit 1
fi

echo "Build successful. Running the program..."
echo "Press Ctrl+D to exit."
./rpn
