cmake_minimum_required(VERSION 3.10)
project(AsmRpn ASM)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin)
set(CMAKE_LINKER ld)
set(CMAKE_EXE_LINKER_FLAGS "-no-pie")
set(CMAKE_ASM_FLAGS "-g")

set(CMAKE_ASM_COMPILER nasm)
set(CMAKE_ASM_COMPILE_OBJECT "<CMAKE_ASM_COMPILER> <DEFINES> <INCLUDES> <FLAGS> -f elf64 -g -o <OBJECT> <SOURCE>")
set(CMAKE_ASM_LINK_EXECUTABLE "<CMAKE_LINKER> <CMAKE_ASM_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")

add_executable(rpn
    src/main.asm
    src/tokenizer.asm
    src/parser.asm
    src/translator.asm
    src/executor.asm
)

enable_testing()