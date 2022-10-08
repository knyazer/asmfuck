#!/bin/sh

gcc -fno-pie -no-pie -o main -g main.s read_file.s brainfuck.s
