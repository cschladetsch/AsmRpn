#!/bin/bash
output=$(echo "1 2 +" | ./bin/rpn --no-color | tr -d '\0' | grep -a "\[[0-9]\+\]" | tail -1 | sed 's/.*\] //')
if [[ "$output" == "3" ]]; then
    echo "PASS"
else
    echo "FAIL: got $output"
fi
