# This program takes an assebmly file input, and generates an executable, giving its path in %rax, or $-1 if something failed along the way
/* vim: set filetype=gas : */

.text

as_enter_msg: .asciz "Starting as\n"
as_error_msg: .asciz "Error when running as\n"

ld_enter_msg: .asciz "Starting ld\n"
ld_error_msg: .asciz "Error when running ld\n"

error_at_fork_msg: .asciz "Error at fork\n"

compilation_success_msg: .asciz "Compilation successful\n"

filename: .asciz "/tmp/compiled_brainfuck_138047.s"
message: .asciz "Here will be the cooooode"

as_path: .asciz "/usr/bin/as"
as_arg1: .asciz "/tmp/compiled_brainfuck_138047.s"
as_arg2: .asciz "-o"
as_arg3: .asciz "/tmp/compiled_brainfuck_138047.o"

ld_path: .asciz "/usr/bin/ld"
ld_args: .asciz "-o /tmp/compiled_brainfuck_138047 /tmp/compiled_brainfuck_138047.o"

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
    
    # Fork the as
    mov $57, %rax
    syscall # sys_fork
    and     %rax, %rax        # rax contains the PID 
# If zero - child, otherwise - parent
    js      error_at_fork   # if negative then there was an error
    jnz     parent          # childs pid returned, go to parent

run_as:
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $as_enter_msg, %rsi          # address of string to output
    mov     $13, %rdx               # number of bytes
    syscall  
    
    # A long preparation for the execve
    xor %rdx, %rdx 
    pushq %rdx
    leaq as_arg3, %r9
    pushq %r9
    leaq as_arg2, %r9
    pushq %r9
    leaq as_arg1, %r9
    pushq %r9
    leaq as_path, %rdi
    pushq %rdi
    movq %rsp, %rsi

    mov $59, %rax # Execve 
    syscall

    # Just end the world in case we are here, as execve should kill the process
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $as_error_msg, %rsi          # address of string to output
    mov     $23, %rdx               # number of bytes
    syscall  
    
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
    jne    end
    
    # Say our message
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $compilation_success_msg, %rsi          # address of string to output
    mov     $24, %rdx               # number of bytes
    syscall  

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

ld_failed:
    # Say that live is bad, ourch child was murdered by error of external binary
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $ld_error_msg, %rsi          # address of string to output
    mov     $20, %rdx               # number of bytes
    syscall  
    
    jmp compiler_exec_end
