cmake_minimum_required(VERSION 3.10)
project(AsmRpn )
enable_language(ASM_NASM)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin)
set(CMAKE_LINKER /usr/bin/ld)
set(CMAKE_EXE_LINKER_FLAGS "-nostdlib -no-pie")
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)
set(CMAKE_ASM_NASM_FLAGS "-g -D BUILD_DATE='${BUILD_DATE}' -I${CMAKE_SOURCE_DIR}/include")

set(CMAKE_ASM_NASM_COMPILER /usr/bin/nasm)
execute_process(COMMAND date -u +%Y-%m-%dT%H:%M:%SZ OUTPUT_VARIABLE BUILD_DATE OUTPUT_STRIP_TRAILING_WHITESPACE)

set(CMAKE_ASM_NASM_COMPILE_OBJECT "<CMAKE_ASM_NASM_COMPILER> <DEFINES> <INCLUDES> <FLAGS> -f elf64 -g -o <OBJECT> <SOURCE>")
set(CMAKE_ASM_NASM_LINK_EXECUTABLE "<CMAKE_LINKER> <CMAKE_ASM_NASM_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")

add_executable(rpn
    src/tokenizer.asm
    src/parser.asm
    src/translator.asm
    src/executor.asm
    src/strings.asm
    src/main.asm
)

enable_testing()

option(ENABLE_LOGGING "Enable runtime logging" OFF)
if(ENABLE_LOGGING)
    add_compile_definitions(ENABLE_LOGGING=1)
endif()
