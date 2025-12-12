#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$ROOT_DIR/build/array_tokenizer"
mkdir -p "$BUILD_DIR"

TOKENIZER_OBJ="$BUILD_DIR/tokenizer_arrays.o"
WRAPPER_OBJ="$BUILD_DIR/tokenizer_wrapper.o"
DRIVER_OBJ="$BUILD_DIR/tokenizer_arrays_driver.o"
HARNESS="$BUILD_DIR/tokenizer_arrays_harness"
DELIM=$'\x1f'

nasm -f elf64 -I"$ROOT_DIR/include" "$ROOT_DIR/src/tokenizer.asm" -o "$TOKENIZER_OBJ"
{ nasm -f elf64 "$ROOT_DIR/tests/tokenize_wrapper.asm" -o "$WRAPPER_OBJ"; }
gcc -std=c11 -Wall -Wextra -pedantic -O0 -fno-pie -c "$ROOT_DIR/tests/tokenizer_arrays_driver.c" -o "$DRIVER_OBJ"
gcc -no-pie "$DRIVER_OBJ" "$TOKENIZER_OBJ" "$WRAPPER_OBJ" -o "$HARNESS"

TESTS=(
  $'EmptyArray\x1f[]\\n\x1f[|]'
  $'ArrayWithSpaces\x1f[ 1 2 3 ]\\n\x1f[|1|2|3|]'
  $'TrailingCommaStyle\x1f[1 2 3 ]\\n\x1f[|1|2|3|]'
  $'NoSpacesBeforeClose\x1f[1 2 3]\\n\x1f[|1|2|3|]'
  $'NestedArrays\x1f[1 [2 3] 4]\\n\x1f[|1|[|2|3|]|4|]'
  $'LeadingNewline\x1f\\n[1 2]\\n\x1f[|1|2|]'
  $'TabsAndSpaces\x1f[\t1\t2\t]\\n\x1f[|1|2|]'
  $'MultipleArrays\x1f[1][2]\\n\x1f[|1|]|[|2|]'
  $'MixedTokens\x1ffoo[1]bar\\n\x1ffoo|[|1|]|bar'
  $'ArrayWithStrings\x1f[ "hi" "bye" ]\\n\x1f[|"hi"|"bye"|]'
  $'ArrayWithStore\x1f[\'x 1 \'y]\\n\x1f[|\'x|1|\'y|]'
  $'ArrayWithVariables\x1f[foo bar baz]\\n\x1f[|foo|bar|baz|]'
  $'NewlineSeparated\x1f[1\\n2\\n3]\\n\x1f[|1|2|3|]'
  $'UnbalancedBrackets\x1f[1 2\\n\x1f[|1|2'
  $'CloseFollowedByNumber\x1f]1]\\n\x1f]|1|]'
  $'OpenBetweenLetters\x1fa[b]c\\n\x1fa|[|b|]|c'
  $'ArrayAfterNumber\x1f1[2 3]\\n\x1f1|[|2|3|]'
  $'ArrayBeforeNumber\x1f[ ]1\\n\x1f[|]|1'
  $'DeeplyNested\x1f[1 [2 [3 [4]]]]\\n\x1f[|1|[|2|[|3|[|4|]|]|]|]'
  $'ArrayWithComments\x1f[1 ; comment\\n2]\\n\x1f[|1|;|comment|2|]'
)

pass=0
fail=0
for entry in "${TESTS[@]}"; do
  IFS=$DELIM read -r name input expected <<<"$entry"
  formatted_input=$(printf "%b" "$input")
  output=$(printf "%s" "$formatted_input" | "$HARNESS")
  if [[ "$output" == "$expected"$'\n' || "$output" == "$expected" ]]; then
    echo "[$name] PASS"
    ((++pass))
  else
    echo "[$name] FAIL"
    echo "  expected: $expected"
    echo "  actual:   ${output//$'\n'/\\n}"
    ((++fail))
  fi
  echo "---"
done

echo "Summary: $pass passed, $fail failed"
if [[ $fail -ne 0 ]]; then
  exit 1
fi
