#!/bin/sh
# Update build date
DATE_STR=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i "s/build_date db .*/build_date db \"$DATE_STR\", 0/" src/main.asm
rm -rf build && mkdir build
cd build && cmake .. && make && ../bin/rpn
