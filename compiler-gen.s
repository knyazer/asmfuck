# This function takes a pointer to the compressed brainfuck representation, and pointer to the location where we want to put our output, and produces assembly code for it at the specified location
/* vim: set filetype=gas : */

.include "jumptable-gen.s"

.text
    _mov: .asciz "\nmovb "
    _addb: .asciz "\naddb "
    _addq: .asciz "\naddq "
    _subb: .asciz "\nsubb "
    _subq: .asciz "\nsubq "
    _jmp: .asciz "\njmp "
    _jne: .asciz "\njne "
    _je: .asciz  "\nje "
    _mul: .asciz "\nmulb "
    _label: .asciz " label_"
    _colon: .asciz ":\n"
    _new_line: .asciz "\n"
    _loop_start_bp: .asciz "\ncmpb $0,(%rbx)\nje"
    
    _print: .asciz "\nmovq $1,%rax\nmovq $1,%rdi\nmovq $1,%rdx\nmovq %rbx,%rsi\nsyscall\n"

    _read: .asciz "\nmovq $0,%rax\nmovq $0,%rdi\nmovq $1,%rdx\nsubq $16,%rsp\nmovq %rsp,%rsi\nsyscall\nmovb (%rsp),%al\nmovb %al,(%rbx)\naddq $16,%rsp\n"

    _rbx: .asciz "%rbx"
    _rbx_wrapped: .asciz "(%rbx)"
    
    _intro: .asciz ".text\n.global _start\n_start:\npushq %rbp\nmovq %rsp,%rbp\nsubq $30000,%rsp\nmovq %rsp,%rbx"
    
    _outro: .asciz "\nmovq %rbp,%rsp\npopq %rbp\nmovq $60, %rax\nmovq $0,%rdi\nsyscall\n"

    _complex_mul: .asciz "movb (%rbx),\n"
    
    _complex_start: .asciz "movb (%rbx),%r15b\n"

    _complex_zero: .asciz "movb $0, (%rbx)\n"

    _complex_mul_1: .asciz "movb $0x"

    _complex_mul_2: .asciz ", %al\nmulb %r15b\naddb %al, (%rbx)\n"

    _complex_sub_mul_1: .asciz "movb $0x"

    _complex_sub_mul_2: .asciz ", %al\nmulb %r15b\nsubb %al, (%rbx)\n"

    _complex_single_mul: .asciz "addb %r15b, (%rbx)\n"

    _complex_sub_single_mul: .asciz "subb %r15b, (%rbx)\n"



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
    
    # Print the intro
    movq %r13, %rdi
    movq $_intro, %rsi
    call add_line
    movq %rax, %r13


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
    movq $_addb, %rsi
    movl %r15d, %edx
    movq $_rbx_wrapped, %rcx
    call construct_line

    movq %rax, %r13
    jmp gen_main_loop

gen_sub:
    # subb v%r15b, (%rbx)
    movq %r13, %rdi
    movq $_subb, %rsi
    movl %r15d, %edx
    movq $_rbx_wrapped, %rcx
    call construct_line
    
    movq %rax, %r13
    jmp gen_main_loop

gen_right:
    # addq v%r15, %rbx
    movq %r13, %rdi
    movq $_addq, %rsi
    movl %r15d, %edx
    movq $_rbx, %rcx
    call construct_line

    movq %rax, %r13
    jmp gen_main_loop

gen_left:
    # subq v%r15, %rbx
    movq %r13, %rdi
    movq $_subq, %rsi
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
    
    decb %r15b
    cmpb $0, %r15b
    jne gen_print

    jmp gen_main_loop

gen_read:
    # movq $0, %rax
    # movq $0, %rdi
    # movq $1, %rdx
    # subq $16, %rsp
    # movq %rsp, %rsi
    # syscall
    # movb (%rsp), %al
    #movb %al, (%r13)
    #addq $16, %rsp
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
    addq $8, %r12 # skip next block with address

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
    addq $8, %r12 # skip next block with address

    jmp gen_main_loop

# Complex operations are here
gen_complex_exit:
    # Just done with the program
    # Add null terminator
    incq %r13
    movb $0, (%r13)

    jmp done

gen_complex_start:
    # We want to put the current block value into %r15
    # movzxb (%rbx), %r15b
    movq %r13, %rdi
    movq $_complex_start, %rsi
    call add_line
    movq %rax, %r13

    addq $8, %r12 # skip next block with address
    jmp gen_main_loop

gen_complex_end:
    # Do nothing

    addq $8, %r12 # skip next block with address
    jmp gen_main_loop

gen_complex_mul:
    # Here we want to add to the current block r15 * repetitions
    # movb repetitons, %al
    # mulb %r15b
    # addb %al, (%rbx)
    movq %r13, %rdi
    movq $_complex_mul_1, %rsi
    call add_line
    movq %rax, %r13

    movq %r13, %rdi
    movzxb %r15b, %rsi
    call print_hex_to_address
    movq %rax, %r13

    movq %r13, %rdi
    movq $_complex_mul_2, %rsi
    call add_line
    movq %rax, %r13

    jmp gen_main_loop

gen_complex_sub_mul:
    # Here we want to subtract from the current block r15 * repetitions
    # movb repetitons, %al
    # mulb %r15b
    # subb %al, (%rbx)
    movq %r13, %rdi
    movq $_complex_sub_mul_1, %rsi
    call add_line
    movq %rax, %r13

    movq %r13, %rdi
    movzxb %r15b, %rsi
    call print_hex_to_address
    movq %rax, %r13

    movq %r13, %rdi
    movq $_complex_sub_mul_2, %rsi
    call add_line
    movq %rax, %r13

    jmp gen_main_loop

gen_complex_single_mul:
    # Here we want to add to the current block r15, without repetitions
    # addb %r15b, (%rbx)
    movq %r13, %rdi
    movq $_complex_single_mul, %rsi
    call add_line

    movq %rax, %r13
    jmp gen_main_loop

gen_complex_sub_single_mul:
    # Here we want to subtract r15 from the current block, without repetitions
    # subb %r15b, (%rbx)
    movq %r13, %rdi
    movq $_complex_sub_single_mul, %rsi
    call add_line

    movq %rax, %r13
    jmp gen_main_loop

gen_complex_zero:
    # Here we want to set the current block to zero
    # movb $0, (%rbx)
    movq %r13, %rdi
    movq $_complex_zero, %rsi
    call add_line

    movq %rax, %r13
    jmp gen_main_loop


# End of instructions list
# Start of functions


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
    movq %rdi, %r8 # Save the pointer to the start of the number
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

    # Now we have to reverse the order of digits
    # We will do it by swapping the first and the last digits, then the second and the second last, and so on
    decq %rdi
    movq %rdi, %r9 # Pointer to the end of the string
    # r8 is Pointer to the start of the string
        
_cl_reverse_loop:
    cmpq %r9, %r8
    jge _cl_reverse_done # If the pointers are equal or crossed, we are done
    
    # Otherwise, we need to swap the digits
    movb (%r9), %al
    movb (%r8), %r10b
    movb %r10b, (%r9)
    movb %al, (%r8)

    incq %r8
    decq %r9
    jmp _cl_reverse_loop

_cl_reverse_done:
#    # Now we have to return the new pointer
    incq %rdi
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
    # Print the outro
    movq %r13, %rdi
    movq $_outro, %rsi
    call add_line
    movq %rax, %r13

    # Restore callee-saved registers
    popq %rbx
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    
    movq %rbp, %rsp         # Stack pointer = base pointer
    popq %rbp               # Restore base pointer
    ret
