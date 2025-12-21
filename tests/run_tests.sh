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
  "LabelAssert|2 'a # a a + 4 eq assert 9|9"
  "LiteralSequence|\"one\" clear 2 2 + 3 +|7"
  "SimpleArray|[1 2 3]|[1 2 3]"
  "EmptyArray|[]|[]"
  "NestedArray|[1 [2 3] 4]|[1 [2 3] 4]"
  "ArrayWithStrings|[\"hello\" \"world\"]|[\"hello\" \"world\"]"
  "ContinuationLiteralDisplay|{ 1 2 + }|{ 1 2 + }"
  "ContinuationNamedLiteral|{ 3 } 'foo # foo|{ 3 }"
  "ContinuationExecuteSimple|{ 42 } &|[42]"
  "ContinuationExecuteMath|{ 5 3 + } &|[8]"
  "ContinuationExecuteString|{\"hello\"} &|[\"hello\"]"
  "ContinuationSuspendResumeBasic|{ 1 { 2 } & ... }|[1, 2]"
  "ContinuationNestedSuspend|{ 1 { 2 { 3 } & ... } & ... }|[1, 2, 3]"
  "ContinuationScopeIsolation|{ 5 'x # { x 1 + } & }|[5, 6]"
  "ContinuationReplaceSimple|{ 7 } !|7"
  "ContinuationReplaceWithCalc|{ 2 3 * } !|6"
  "ContinuationResumeError|...|;msg=Resume: not in continuation"
  "ContinuationReplaceError|1 !|;msg=Replace: expected continuation"
  "ContinuationSuspendError|&|;msg=Suspend: expected continuation"
  "ContinuationWithVariables|{ 'x # x 10 + } 'x # 5 &|15"
  "ContinuationStackPreserve|{ 1 2 { 3 4 } & + + + } &|[10]"
  "ContinuationEmpty|{ } &|"
  "ContinuationSingleLiteral|{ 99 } &|99"
  "ContinuationArithmetic|{ 10 20 * 5 / } &|40"
  "ContinuationStringConcat|{\"a\" \"b\" +} &|\"ab\""
  "ContinuationNestedBraces|{ { 1 } & } &|1"
  "ContinuationWithArray|{ [1 2] } &|[1 2]"
  "ContinuationResumeMid|{ 1 2 { 3 ... } & + }|[1, 5]"
  "ContinuationReplaceTailCall|{ 4 { 5 } ! } &|5"
  "ContinuationScopeSnapshot|{ 100 'y # { y } & y } 'y # 200 &|[100, 200]"
  "ContinuationDeepNesting|{ 1 { 2 { 3 } & } & } &|[1, 2, 3]"
  "ContinuationErrorInCont|{ 1 + } &|;msg=Stack underflow"
  "ContinuationResumeAfterSuspend|{ { 1 ... } & 2 } &|[1, 2]"
  "ContinuationMultipleSuspends|{ 1 { 2 } & { 3 } & ... ... }|[1, 2, 3]"
  "ContinuationVariableInCont|{ 'a # { a 1 + 'a # } & a }|[2, 2]"
  "ContinuationReplaceLoop|{ { 1 + dup 10 < { } ! ... } ! } 'loop # 0 loop|10"
  "ContinuationBasic1|{ 1 } &|1"
  "ContinuationBasic2|{ 2 3 + } &|5"
  "ContinuationBasic3|{ 4 5 * } &|20"
  "ContinuationBasic4|{ 6 2 / } &|3"
  "ContinuationBasic5|{ 7 3 - } &|4"
  "ContinuationBasic6|{ 8 2 swap / } &|4"
  "ContinuationBasic7|{ 9 dup + } &|18"
  "ContinuationBasic8|{ 10 drop 11 } &|11"
  "ContinuationBasic9|{ 12 clear 13 } &|13"
  "ContinuationBasic10|{ 14 over + } &|28"
  "ContinuationString1|{\"test\"} &|\"test\""
  "ContinuationString2|{\"a\" \"b\" +} &|\"ab\""
  "ContinuationString3|{\"x\" clear \"y\"} &|\"y\""
  "ContinuationArray1|{ [1] } &|[1]"
  "ContinuationArray2|{ [1 2 3] } &|[1 2 3]"
  "ContinuationArray3|{ [] } &|[]"
  "ContinuationVariable1|{ 1 'v # v } &|1"
  "ContinuationVariable2|{ 2 'v # { v 1 + } & v }|[3, 2]"
  "ContinuationVariable3|{ 3 'v # { v 1 + 'v # } & v }|[4, 4]"
  "ContinuationSuspend1|{ 1 { 2 } & }|[1, <cont>]"
  "ContinuationSuspend2|{ 1 { 2 } & ... }|[1, 2]"
  "ContinuationSuspend3|{ 1 { 2 3 } & ... }|[1, 2, 3]"
  "ContinuationReplace1|{ 1 { 2 } ! }|[2]"
  "ContinuationReplace2|{ 1 { 2 3 + } ! }|[5]"
  "ContinuationReplace3|{ 1 { 2 } ! 4 }|[2, 4]"
  "ContinuationNested1|{ { 1 } & } &|1"
  "ContinuationNested2|{ { 2 { 3 } & } & } &|[2, 3]"
  "ContinuationError1|{ + } &|;msg=Stack underflow"
  "ContinuationError2|{ 1 2 + + } &|;msg=Stack underflow"
  "ContinuationError3|{ ... } &|;msg=Resume: not in continuation"
  "ContinuationError4|{ ! } &|;msg=Replace: expected continuation"
  "ContinuationComplex1|{ 1 { 2 } & { 3 } & ... ... + }|[1, 5]"
  "ContinuationComplex2|{ 5 'x # { x 1 + } & x }|[6, 5]"
  "ContinuationComplex3|{ { dup 1 + dup 5 < { } ! ... } ! } 0 !|5"
  "ContinuationComplex4|{ 1 { 2 } & clear 3 }|[3]"
  "ContinuationComplex5|{ [1 2] { length } & }|[1, 2, 2]"
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
    actual=$(echo "$output" | sed -n '/λ/,$ p' | tail -1 | sed 's/λ//' | sed 's/^ *//' | sed 's/ *$//' | tr -d '\n')
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
