#!/bin/sh

gcc -fno-pie -no-pie -g main.s -o main && ./main $1 $2 $3
