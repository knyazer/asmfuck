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
    _label: .asciz " label_"
    _colon: .asciz ": \n"
    _new_line: .asciz "\n"
    _loop_start_bp: .asciz "\n    cmpb $0, (%rbx)\n    je"
    
    _print: .asciz "\n    movq $1, %rax\n    movq $1, %rdi\n    movq $1, %rdx\n    movzxb (%rbx), %rsi\n    syscall\n"

    _read: .asciz "\n    movq $0, %rax\n    movq $0, %rdi\n    movq $1, %rdx\n    subq $16, %rsp\n    movq %rsp, %rsi\n    syscall\n    movb (%rsp), %al\n    movb %al, (%r13)\n    addq $16, %rsp\n"

    _rbx: .asciz "%rbx"
    _rbx_wrapped: .asciz "(%rbx)"


compile_to_string:
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
    subq $8, %r12
gen_main_loop:
    addq $8, %r12
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
    # label_xxx:
    #     cmpb $0, (%rbx)
    #     je label_yyy

    # In the next block from the loop start we have stored the address of the block after the loop end
    # Lets use it in hex form, as a xxx and yyy. We will use the same format for all labels
    # So, yyy = 8(%r12), qword; xxx = %r12, qword
    
    movq %r13, %rdi
    movq %r12, %rsi
    call print_label_with_colon
    movq %rax, %r13
    
    # Next line!
    movq %r13, %rdi
    movq $_loop_start_bp, %rsi
    call add_line
    movq %rax, %r13

    # Last label!
    movq %r13, %rdi
    movq 8(%r12), %rsi
    call print_label
    movq %rax, %r13

    # and new line
    movq %r13, %rdi
    movq $_new_line, %rsi
    call add_line
    movq %rax, %r13
    
    # Done

    jmp gen_main_loop

gen_loop_end:
    #     jmp label_xxx
    # label_yyy:
    movq %r13, %rdi
    movq $_jmp, %rsi
    call add_line
    movq %rax, %r13
    # Current state: jmp
    
    movq %r13, %rdi
    movq 8(%r12), %rsi
    call print_label
    movq %rax, %r13
    # Current state: jmp label_xxx

    # and new line
    movq %r13, %rdi
    movq $_new_line, %rsi
    call add_line
    movq %rax, %r13
    
    # and label
    movq %r13, %rdi
    movq %r12, %rsi
    call print_label_with_colon
    movq %rax, %r13

    # Done
    
    jmp gen_main_loop

# Complex operations are here
gen_complex_exit:
    # Just done with the program
    # Add null terminator
    incq %r13
    movb $0, (%r13)

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

    jmp add_line_loop

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

    jmp construct_line_first_loop

construct_line_first_loop_done:
    # Now, we have reached interesting stuff. The first thing is to render the number of repetitions, which is in %edx. How do we do that? Simple: print 8 digits in hex.
    
    # Firstly, print hex prefix $0x
    movb $'$', (%rdi)
    movb $'0', 1(%rdi)
    movb $'x', 2(%rdi)
    addq $3, %rdi

    # rdi is correct, rsi is not
    movl %edx, %esi # Move the number to the second param
    call print_hex_to_address

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

    jmp construct_line_second_loop
    
construct_line_second_loop_done:
    # Now we need to add '\n' to the dest, as the final thing
    movb $'\n', (%rdi)
    incq %rdi

    # Now we are completly done, and we can return the pointer to the new end of the string
    movq %rdi, %rax

    movq %rbp, %rsp
    popq %rbp
    ret

print_hex_to_address:
    construct_number_loop:
    # Lets take first 4 bits of the %esi, second param, and transform it into a hex digit
    movq %rsi, %rax
    andq $0xF, %rax
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
    shrq $4, %rsi
    # And repeat the process until %rsi is 0
    cmpq $0, %rsi
    jne construct_number_loop
    
    # Now we have to return the new pointer
    movq %rdi, %rax
    ret

print_label:
    movq %rdi, %r8
    movq %rsi, %r9
    
    movq %r8, %rdi
    movq $_label, %rsi
    call add_line
    movq %rax, %r8
    # Current state: label_
    
    movq %r8, %rdi
    movq %r9, %rsi
    call print_hex_to_address
    movq %rax, %r8
    # Current state: label_1234
    
    movq %r8, %rax
    ret

print_label_with_colon:
    movq %rdi, %r8
    movq %rsi, %r9
    
    movq %r8, %rdi
    movq $_label, %rsi
    call add_line
    movq %rax, %r8
    # Current state: label_
    
    movq %r8, %rdi
    movq %r9, %rsi
    call print_hex_to_address
    movq %rax, %r8
    # Current state: label_1234
    
    movq %r8, %rdi
    movq $_colon, %rsi
    call add_line
    movq %rax, %r8
    # Current state: label_1234:
    
    movq %r8, %rax
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
