# RPN Calculator in Assembly

This is a simple Reverse Polish Notation (RPN) calculator implemented in x86-64 assembly language using NASM syntax.

## Features

- REPL (Read-Eval-Print Loop) for interactive calculations
- Supports basic arithmetic operations: +, -, *, /
- Handles integers (positive and negative)
- Error handling for stack underflow, invalid input, and division by zero
- Prints the top of the stack after each operation

## Usage

1. Assemble the code:
   ```
   nasm -f elf64 rpn.asm -o rpn.o
   ```

2. Link the object file:
   ```
   ld rpn.o -o rpn
   ```

3. Run the calculator:
   ```
   ./rpn
   ```

4. Enter RPN expressions, e.g.:
   ```
   > 3 4 +
   7
   > 5 2 -
   3
   > 10 2 /
   5
   ```

5. Press Ctrl+D to exit.

## How it works

- Numbers are pushed onto the stack
- Operators pop the required operands, perform the operation, and push the result
- The REPL reads a line, parses tokens separated by spaces, and processes each token
- After processing the line, the top of the stack is printed (if not empty)

## Limitations

- Only integer arithmetic
- No floating point support
- Stack size limited to 100 elements
- Simple parsing, no advanced error recovery