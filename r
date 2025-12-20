#!/bin/bash
cmake .
make
./tests/run_tests.sh
