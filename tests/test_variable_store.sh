#!/bin/bash
output=$($1 < $2)
echo "Output: '$output'" >&2
if echo "$output" | grep -q '42'; then
    echo "Found 42" >&2
    exit 0
else
    echo "No 42" >&2
    exit 1
fi
