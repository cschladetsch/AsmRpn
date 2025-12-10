# AsmRpn - RPN Calculator in Assembly

This is a modular Reverse Polish Notation (RPN) calculator implemented in x86-64 assembly language using NASM syntax.

## Demo

[Demo](/Resources/Demo1.gif)

## Features

- REPL (Read-Eval-Print Loop) for interactive calculations
- Supports basic arithmetic operations: +, -, *, /
- Variable support with C-style naming (start with letter or _, contain letters, digits, _)
- Store operation using ' (e.g., 'var to store to variable)
- Modular architecture: tokenizer, parser, translator, executor
- CMake-based build system
- Automated tests
- Prints the top of the stack after each operation

## Build

1. Ensure you have CMake and NASM installed.

2. Build the project:
   ```
   mkdir build
   cd build
   cmake ..
   make
   ```

3. Run the calculator:
   ```
   ../bin/rpn
   ```

4. Run tests:
   ```
   ctest
   ```
   Tests use input files in the `tests/` directory.

5. Enter RPN expressions, e.g.:
   ```
   > 3 4 +
   7
   > 5 2 -
   3
   > 10 2 /
   5
   > 42 'answer
   > answer
   42
   ```

6. Press Ctrl+D to exit.

## How it works

The calculator is structured in modules:

- **Tokenizer** (`tokenizer.asm`): Splits input into tokens
- **Parser** (`parser.asm`): Parses tokens into operations
- **Translator** (`translator.asm`): Translates operations to bytecode
- **Executor** (`executor.asm`): Executes bytecode on the stack

- Numbers and variables are pushed onto the stack
- Operators pop operands, perform operations, and push results
- Variables use C-style names and are stored in a hash table
- The REPL reads input, tokenizes, parses, translates, executes, and prints the stack

## Limitations

- Only integer arithmetic
- No floating point support
- Stack size limited to 100 elements
- Simple parsing, no advanced error recovery
