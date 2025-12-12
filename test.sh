#!/bin/bash
output=$(echo "1 2 +" | ./bin/rpn --no-color | grep -a "\[[0-9]\+\]" | tail -1 | sed 's/.*\] //' | sed 's/^ *//' | sed 's/ *$//' | tr -d '\n')
if [[ "$output" == "3" ]]; then
    echo "PASS"
else
    echo "FAIL: got $output"
fi
