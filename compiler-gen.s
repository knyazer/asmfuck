# This function takes a pointer to the compressed brainfuck representation, and pointer to the location where we want to put our output, and produces assembly code for it at the specified location
/* vim: set filetype=gas : */

.include "jumptable-gen.s"

.text
    _mov: .asciz "\n    mov "
    _add: .asciz "\n    add "
    _sub: .asciz "\n    sub "
    _jmp: .asciz "\n    jmp "
    _jne: .asciz "\n    jne "
    _je: .asciz  "\n    je  "
    _mul: .asciz "\n    mul "
    
    _print: .asciz "\n    movq $1, %rax\n    movq $1, %rdi\n    movq $1, %rdx\n    movzxb (%rbx), %rsi\n    syscall\n"

    _read: .asciz "\n    movq $0, %rax\n    movq $0, %rdi\n    movq $1, %rdx\n    subq $16, %rsp\n    movq %rsp, %rsi\n    syscall\n    movb (%rsp), %al\n    movb %al, (%r13)\n    addq $16, %rsp\n"

    _rbx: .asciz "%rbx"
    _rbx_wrapped: .asciz "(%rbx)"


generate_asm_from_bf:
    pushq %rbp              # Push base pointer to stack
    movq %rsp, %rbp         # Base pointer = stack pointer 
    
    # Save callee-saved registers
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    pushq %rbx
    
    # Here is the main loop
    # Pointer to the current block - r12
    movq %rdi, %r12
    # Pointer to the output - r13
    movq %rsi, %r13

    # Main loop
gen_main_loop:
    # Get the operation on the current block
    movzxb 4(%r12), %r10
    # Get the number of repetitions of the current block
    movq $0, %r15 # Clear the register
    movl (%r12), %r15d
    
    # If we are not done, jump to the suitable subroutine
    shlq $3, %r10
    movq jumptable_gen(%r10), %r10
    jmp *%r10

    # If we are here something went wrong, but i dont care
    jmp gen_main_loop

# In the assembly produced the register %rbx is the pointer to the current bf memory cell, and %rip is instruction pointer
gen_add:
    # addb v%r15b, (%rbx)
    movq %r13, %rdi
    movq $_add, %rsi
    movl %r15d, %edx
    movq $_rbx_wrapped, %rcx
    call construct_line

    movq %rax, %r13
    jmp gen_main_loop

gen_sub:
    # subb v%r15b, (%rbx)
    movq %r13, %rdi
    movq $_sub, %rsi
    movl %r15d, %edx
    movq $_rbx_wrapped, %rcx
    call construct_line
    
    movq %rax, %r13
    jmp gen_main_loop

gen_right:
    # addq v%r15, %rbx
    movq %r13, %rdi
    movq $_add, %rsi
    movl %r15d, %edx
    movq $_rbx, %rcx
    call construct_line

    movq %rax, %r13
    jmp gen_main_loop

gen_left:
    # subq v%r15, %rbx
    movq %r13, %rdi
    movq $_sub, %rsi
    movl %r15d, %edx
    movq $_rbx, %rcx
    call construct_line

    movq %rax, %r13
    jmp gen_main_loop

gen_print:
    # movq $1, %rax
    # movq $1, %rdi
    # movq $1, %rdx
    # movzxb (%rbx), %rsi
    # syscall
    movq %r13, %rdi
    movq $_print, %rsi
    call add_line

    movq %rax, %r13
    jmp gen_main_loop

gen_read:
    # movq $0, %rax
    # movq $0, %rdi
    # movq $1, %rdx
    # subq $16, %rsp
    # movq %rsp, %rsi
    # syscall
    # movb (%rsp), %al
    # movb %al, (%r13)
    # addq $16, %rsp
    movq %r13, %rdi
    movq $_read, %rsi
    call add_line

    movq %rax, %r13
    jmp gen_main_loop

gen_loop_start:
    jmp gen_main_loop

gen_loop_end:
    jmp gen_main_loop

# Complex operations are here
gen_complex_exit:
    jmp done

gen_complex_start:
    jmp gen_main_loop

gen_complex_end:
    jmp gen_main_loop

gen_complex_mul:
    jmp gen_main_loop

gen_complex_sub_mul:
    jmp gen_main_loop

gen_complex_single_mul:
    jmp gen_main_loop

gen_complex_double_mul:
    jmp gen_main_loop

gen_complex_sub_single_mul:
    jmp gen_main_loop

gen_complex_sub_double_mul:
    jmp gen_main_loop

gen_complex_zero:
    jmp gen_main_loop

add_line:
    pushq %rbp
    movq %rsp, %rbp
    
    # Pointer to the dest - rdi, first param
    # Pointer to the source - rsi, second param
    
add_line_loop:
    # Check that we are at the end of the string
    cmpb $0, (%rsi)
    je add_line_done
    
    # If we are not, add the current character to the dest
    movb (%rsi), %al
    movb %al, (%rdi)

    incq %rdi
    incq %rsi

add_line_done:
    movq %rdi, %rax # Return the pointer to the end of the string

    movq %rbp, %rsp
    popq %rbp
    ret

construct_line:
    pushq %rbp
    movq %rsp, %rbp

    # Pointer to the dest - rdi, first param
    # Pointer to the source - rsi, second param
construct_line_first_loop:
    # Check that we are at the end of the string
    cmpb $0, (%rsi)
    je construct_line_first_loop_done
    
    # If we are not, add the current character to the dest
    movb (%rsi), %al
    movb %al, (%rdi)
    
    incq %rdi
    incq %rsi

construct_line_first_loop_done:
    # Now, we have reached interesting stuff. The first thing is to render the number of repetitions, which is in %edx. How do we do that? Simple: print 8 digits in hex.

construct_number_loop:
    # Lets take first 4 bits of the %edx, and transform it into a hex digit
    movl %edx, %eax
    andl $0xF, %eax
    # Now there is a number in %eax, which is between 0 and 15. We need to transform it into a hex digit
    cmpb $10, %al # If the number is greater or equal than 10, we need to add code of letter 'A' to it
    jge _cl_add_A_to_al
    # Otherwise we need to add code of '0'
    addb $'0', %al
    jmp _cl_al_done

_cl_add_A_to_al:
    addb $'A' - 10, %al
    
_cl_al_done:
    # Now we have the hex digit in %al, and we need to add it to the dest
    movb %al, (%rdi)
    incq %rdi
    
    # Now we need to shift the %edx to the right by 4 bits
    shrl $4, %edx
    # And repeat the process until %edx is 0
    cmpl $0, %edx
    jne construct_number_loop

    # Now we need to add ' , ' to the dest
    movb $' ', (%rdi)
    movb $',', 1(%rdi)
    movb $' ', 2(%rdi)
    addq $3, %rdi

    # Now we need to add the last param, which is in %rcx, to the dest
construct_line_second_loop:
    # Check that we are at the end of the string
    cmpb $0, (%rcx)
    je construct_line_second_loop_done

    # If we are not, add the current character to the dest
    movb (%rcx), %al
    movb %al, (%rdi)

    incq %rdi
    incq %rcx
    
construct_line_second_loop_done:
    # Now we need to add '\n' to the dest, as the final thing
    movb $'\n', (%rdi)
    incq %rdi

    # Now we are completly done, and we can return the pointer to the new end of the string
    movq %rdi, %rax

    movq %rbp, %rsp
    popq %rbp
    ret

done:
    # Restore callee-saved registers
    popq %rbx
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    
    movq %rbp, %rsp         # Stack pointer = base pointer
    popq %rbp               # Restore base pointer
    ret
