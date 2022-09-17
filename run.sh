#!/bin/sh

as -o main.o main.s && ld -o main main.o && ./main $1
