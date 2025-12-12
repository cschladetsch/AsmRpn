#!/bin/bash
set -u

BIN=./bin/rpn
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
  "StoreLoad|42 'answer answer|42"
  "VariableOverwrite|7 'x 5 'x x|5"
  "VariableSum|100 'bar 50 'baz baz bar +|150"
)

pass=0
fail=0
for entry in "${TESTS[@]}"; do
    IFS='|' read -r name input expected <<<"$entry"
    output=$(printf "%s\n" "$input" | "$BIN" --no-color | tr -d '\0')
    actual=$(echo "$output" | grep -a '\[0\]' | tail -1 | sed 's/.*\[0\] //')
    if [[ "$actual" == "$expected" ]]; then
        echo "[$name] PASS (expected=$expected)"
        ((pass++))
    else
        echo "[$name] FAIL (expected=$expected got=${actual:-<none>})"
        echo "Output:\n$output"
        ((fail++))
    fi
    echo "---"
done

echo "Summary: $pass passed, $fail failed"
if [[ $fail -ne 0 ]]; then
    exit 1
fi
