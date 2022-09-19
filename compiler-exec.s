# This program takes an assebmly file input, and generates an executable, giving its path in %rax, or $-1 if something failed along the way

.text

child_msg: .asciz "I am a child! \n"
parent_msg: .asciz "I am a parent! \n"
waiting_msg: .asciz "Waiting for child to finish... \n"
child_alive_from_inside: .asciz "Executable not found. \n"
error_at_child_msg: .asciz "Error at child process, non zero return code. \n"


.global main
    path: .asciz "__t.sh"
    args: .asciz ""

main:
    pushq $0
    mov $57, %rax
    syscall # sys_fork
    and     %rax, %rax        # rax contains the PID 
# If zero - child, otherwise - parent
    js      error_at_fork   # if negative then there was an error
    jnz     parent          # childs pid returned, go to parent

child:
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $child_msg, %rsi          # address of string to output
    mov     $14, %rdx               # number of bytes
    syscall  

# Run some script
run_script:
    xor %rax, %rax
    xor %rdx, %rdx

    pushq %rdx

    push path
    movq %rsp, %rdi

    pushq args
    movq %rsp, %rsi

    push %rax
    push %rsi
    push %rdi

    mov %rsp, %rsi
    mov $59, %rax # Execve 
    syscall

    # Just end the world in case we are here, as execve should kill the process
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $child_alive_from_inside, %rsi          # address of string to output
    mov     $24, %rdx               # number of bytes
    syscall  
    
    mov     $60, %rax          # sys_exit
    mov     $1, %rdi          # exit code 1 means that something went wrong, as a execve failed
    syscall

parent:
    mov     %rax, %r12              # save childs pid
    
    # Say that we are waiting for child
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $waiting_msg, %rsi          # address of string to output
    mov     $32, %rdx               # number of bytes
    syscall 

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
    jne    error_at_child
    
    # Say our message
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $parent_msg, %rsi          # address of string to output
    mov     $16, %rdx               # number of bytes
    syscall  

    mov    $60, %rax          # sys_exit
    mov     $0, %rdi          # exit code
    syscall

error_at_fork:
    mov $60, %rax
    mov $3, %rdi
    syscall

error_at_child:
    # Say that live is bad, ourch child was murdered by error of external binary
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $error_at_child_msg, %rsi          # address of string to output
    mov     $48, %rdx               # number of bytes
    syscall  
    
    mov $60, %rax
    mov $4, %rdi
    syscall
