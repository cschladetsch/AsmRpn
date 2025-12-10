#!/bin/bash
output=$(echo "1 2 +" | ./bin/rpn | grep -a "\[0\]" | tail -1 | sed 's/.*\[0\] \([0-9]*\).*/\1/')
if [[ "$output" == "3" ]]; then
    echo "PASS"
else
    echo "FAIL: got $output"
fi
