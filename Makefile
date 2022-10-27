all:

	gcc -fno-pie -no-pie -g main.s read_file.s brainfuck.s
