#!/bin/bash
output=$($1 < $2)
if echo "$output" | grep -q '42'; then
    exit 0
else
    exit 1
fi