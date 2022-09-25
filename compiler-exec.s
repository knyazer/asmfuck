# This program takes an assebmly file input, and generates an executable, giving its path in %rax, or $-1 if something failed along the way
/* vim: set filetype=gas : */

.text

compilation_enter_message: .asciz "Compilation started\n"
compilation_error_message: .asciz "Compilation failed\n"
compilation_success_message: .asciz "Compilation successful\n"

error_at_fork_msg: .asciz "Error at fork\n"

filename: .asciz "/tmp/compiled_brainfuck_138047.s"

# to compile the thing we use the following script:
# sh -c '$(which as) -o /tmp/compiled_brainfuck_138047.o /tmp/compiled_brainfuck_138047.s && $(which ld) -o /tmp/compiled_brainfuck_138047 /tmp/compiled_brainfuck_138047.o'

sh_path_2: .asciz "/bin/sh"

sh_path: .asciz "/usr/bin/sh"

sh_arg_1: .asciz "-c"
sh_arg_2: .asciz "as -o /tmp/compiled_brainfuck_138047.o /tmp/compiled_brainfuck_138047.s 2> /dev/null && ld -o /tmp/compiled_brainfuck_138047 /tmp/compiled_brainfuck_138047.o 2> /dev/null"

executable_path: .asciz "/tmp/compiled_brainfuck_138047"

# The first argument is the address of the string, %rdi
# The second argument is the length of the string, %rsi
compile_from_string:
    pushq %rbp
    movq %rsp, %rbp

    movq %rdi, %r8  # Save the data address
    movq %rsi, %r9 # Save the data length

    # Create a file
    movq $85, %rax
    movq $511, %rsi
    movq $filename, %rdi
    syscall

    movq %rax, %r10 # Save the file descriptor

    # Write to the file
    movq $1, %rax
    movq %r9, %rdx
    movq %r10, %rdi
    movq %r8, %rsi
    syscall
    
    # Fork the compiler
    mov $57, %rax
    syscall # sys_fork
    and     %rax, %rax        # rax contains the PID 
# If zero - child, otherwise - parent
    js      error_at_fork   # if negative then there was an error
    jnz     parent          # childs pid returned, go to parent

run_shell:
    #mov     $1, %rax                # system call 1 is write
    #mov     $1, %rdi                # file handle 1 is stdout
    #mov     $compilation_enter_message, %rsi          # address of string to output
    #mov     $13, %rdx               # number of bytes
    #syscall  
    
    # A long preparation for the execve
    xor %rdx, %rdx 
    pushq %rdx
    leaq sh_arg_2, %r9
    pushq %r9
    leaq sh_arg_1, %r9
    pushq %r9
    leaq sh_path, %rdi
    pushq %rdi
    movq %rsp, %rsi

    mov $59, %rax # Execve 
    syscall

    # Just end the world in case we are here, as execve should kill the process
    #mov     $1, %rax                # system call 1 is write
    #mov     $1, %rdi                # file handle 1 is stdout
    #mov     $compilation_error_message, %rsi          # address of string to output
    #mov     $23, %rdx               # number of bytes
    #syscall  
    
    # Exit with code 1, as we need to tell the parent that something failed
    mov $60, %rax
    mov $1, %rdi
    syscall

parent:
    mov     %rax, %r12              # save childs pid
    
    # Wait until child finishes
    pushq $0
    mov     $61, %rax
    mov     %r12, %rdi
    mov     %rsp, %rsi
    mov     $0, %rdx
    syscall

    # Check that kiddo is dead (worked well, which means it returned 0)
    movq (%rsp), %rax
    cmp $0, %rax
    jne compilation_failed
    
    # Fork
    mov $57, %rax
    syscall # sys_fork
    and     %rax, %rax        # rax contains the PID
    # If zero - child, otherwise - parent
    
    js error_at_fork
    jnz parent_final

run_executable:
    #mov     $1, %rax                # system call 1 is write
    #mov     $1, %rdi                # file handle 1 is stdout
    #mov     $executable_enter_message, %rsi          # address of string to output
    #mov     $13, %rdx               # number of bytes
    #syscall  
    
    # A long preparation for the execve
    xor %rdx, %rdx 
    pushq %rdx
    leaq executable_path, %rdi
    pushq %rdi
    movq %rsp, %rsi

    mov $59, %rax # Execve 
    syscall

    # Exit with code 1, as we need to tell the parent that something failed
    mov $60, %rax
    mov $1, %rdi
    syscall

parent_final:
    movq %rax, %r12 # Save the childs pid

    # Wait until child finishes
    pushq $0
    mov     $61, %rax
    mov     %r12, %rdi
    mov     %rsp, %rsi
    mov     $0, %rdx
    syscall

    # now we do not really care what happened, as it should be fine anyways
    # so we just exit with code 0
    jmp success

compiler_exec_end:
    # Cleanup the stack
    movq %rbp, %rsp
    popq %rbp
    ret

error_at_fork:
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $error_at_fork_msg, %rsi          # address of string to output
    mov     $30, %rdx               # number of bytes
    syscall  
    jmp compiler_exec_end

compilation_failed:
    movq $1, %rax
    jmp compiler_exec_end

success:
    movq $0, %rax
    jmp compiler_exec_end

