#!/bin/bash
set -u
set -o pipefail
BIN="$(cd "$(dirname "$0")/.." && pwd)/bin/rpn"
if [[ ! -x "$BIN" ]]; then
  echo "error: $BIN not built" >&2
  exit 1
fi
cases=(
  "DepthEmpty|depth|0"
  "DepthAfterPush|1 depth|1"
  "DupWord|5 dup|5"
  "OverWord|1 2 over|1"
  "RotWord|1 2 3 rot|2"
  "EqWord|5 5 eq|1"
  "GtWord|2 1 gt|1"
  "LtWord|1 2 lt|1"
  "TrueLiteral|true|1"
  "FalseLiteral|false|0"
  "AssertWord|true assert 9|9"
  "LabelStoreAssert|2 'a # a a + 4 eq assert 7|7"
)
pass=0
fail=0
for entry in "${cases[@]}"; do
  IFS='|' read -r name program expected <<<"$entry"
  if ! output=$(printf '%s\n' "$program" | "$BIN" --no-color | tr -d '\0'); then
    echo "[$name] FAIL (runtime error)"
    echo "$output"
    ((fail++))
    echo '---'
    continue
  fi
  actual=$(echo "$output" | grep -a '\[[0-9]\+\]' | tail -1 | sed 's/.*\] //' | sed 's/^ *//' | sed 's/ *$//' | tr -d '\n')
  if [[ "$actual" == "$expected" ]]; then
    echo "[$name] PASS"
    ((pass++))
  else
    echo "[$name] FAIL expected=$expected got=${actual:-<none>}"
    echo "$output"
    ((fail++))
  fi
  echo '---'
done
printf 'Summary: %d passed, %d failed\n' "$pass" "$fail"
if [[ $fail -ne 0 ]]; then
  exit 1
fi
