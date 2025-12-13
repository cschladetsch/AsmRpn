#!/bin/bash
set -u

BIN="$(cd "$(dirname "$0")/.." && pwd)/bin/rpn"
if [[ ! -x "$BIN" ]]; then
    echo "error: $BIN not found or not executable" >&2
    exit 1
fi

TESTS=(
  "Addition|1 2 +|3"
  "Subtraction|10 4 -|6"
  "Multiplication|6 7 *|42"
  "Division|20 5 /|4"
  "NegativeMultiply|-3 -4 *|12"
  "CompositeExpr|5 1 2 + 4 * + 3 -|14"
  "DijkstraExample|15 7 1 1 + - / 3 * 2 1 1 + + -|5"
  "StoreLoad|42 'answer # answer|42"
  "VariableOverwrite|7 'x # 5 'x # x|5"
  "VariableSum|100 'bar # 50 'baz # baz bar +|150"
  "ClearKeepsFinal|1 2 clear 5|5"
  "DropRemovesTop|4 9 drop|4"
  "SwapAffectsOrder|3 10 swap -|7"
  "UnderflowError|1 +|1;msg=Stack underflow"
  "StringLiteral|\"hello\"|\"hello\""
  "StringWithSpace|\"foo bar\"|\"foo bar\""
  "StringEscapedQuote|\"foo \\\"bar\"|\"foo \"bar\""
  "StringStoreLoad|\"hi\" 'g # g|\"hi\""
  "StringConcat|\"foo\" \"bar\" +|\"foobar\""
  "DoubleConcat|\"a\" \"b\" + \"c\" +|\"abc\""
  "NestedClear|1 2 + clear 9|9"
  "StoreAfterClear|5 'x # clear x|5"
  "DivisionFloor|-7 3 /|-2"
  "MixedOps|10 5 - 2 * 3 +|13"
  "WhitespaceHandling|  8   4    /|2"
  "CarriageReturn|5 5 +$(printf '\r')|10"
  "EmptyInput||"
  "RepeatAddition|1 1 + +|;msg=Stack underflow"
  "VariableChain|1 'a # a 'b # b 'c # c|1"
  "LongStringConcat|\"hello\" \" \" + \"world\" +|\"hello world\""
  "SwapStrings|\"left\" \"right\" swap +|\"rightleft\""
  "NegativeDivision|-9 -3 /|3"
  "StringThenMath|\"foo\" clear 1 2 +|3"
  "StackGrowth|$(printf '1 %.0s' {1..10}) clear|"
  "MultiVariableMath|1 'a # 2 'b # 3 'c # a b + c +|6"
  "StoreStringAndAdd|\"x\" 's # s \"y\" +|\"xy\""
  "VariableStringConcat|\"foo\" 'a # \"bar\" 'b # a b +|\"foobar\""
  "StringConcatAfterClear|\"hi\" clear \"there\"|\"there\""
  "LiteralSequence|\"one\" clear 2 2 + 3 +|7"
  "SimpleArray|[1 2 3]|"[1 2 3]""
  "EmptyArray|[]|"[]""
  "NestedArray|[1 [2 3] 4]|"[1 [2 3] 4]""
  "ArrayWithStrings|[\"hello\" \"world\"]|"["hello" "world"]""
)

pass=0
fail=0
for entry in "${TESTS[@]}"; do
    IFS='|' read -r name input expectation <<<"$entry"
    expected="$expectation"
    expected_msg=""
    if [[ "$expected" == *";msg="* ]]; then
        expected_msg="${expected#*;msg=}"
        expected="${expected%%;msg=*}"
    fi
    output=$(printf "%s\n" "$input" | "$BIN" --no-color | tr -d '\0')
    actual=$(echo "$output" | grep -a '\[[0-9]\+\]' | tail -1 | sed 's/.*\] //' | sed 's/^ *//' | sed 's/ *$//' | tr -d '\n')
    test_ok=1
    if [[ -n "$expected" ]]; then
        if [[ "$actual" != "$expected" ]]; then
            test_ok=0
            echo "[$name] FAIL (expected=$expected got=${actual:-<none>})"
            echo "Output:\n$output"
        fi
    fi
    if [[ -n "$expected_msg" ]]; then
        if ! echo "$output" | grep -q "$expected_msg"; then
            test_ok=0
            echo "[$name] FAIL (missing message '$expected_msg')"
            echo "Output:\n$output"
        fi
    fi
    if [[ $test_ok -eq 1 ]]; then
        echo "[$name] PASS (expected=$expectation)"
        ((pass++))
    else
        ((fail++))
    fi
    echo "---"

done

echo "Summary: $pass passed, $fail failed"
if [[ $fail -ne 0 ]]; then
    exit 1
fi
