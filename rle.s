# This file provides a function rle_encode which allows to encode the string using RLE
/* vim: set filetype=gas : */

.text

# %rdi - first arg - pointer to the beginning of the raw string
# %rsi - second arg - pointer to the beginning of the output
rle_encode:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    
    # The block structure is as follows:
    # [4 bytes] - number of repetitions
    # [1 byte] - command
    # [3 bytes] - reserved (padding to 8 bytes)

    # Let rdi be the pointer to the current character of the raw string
    # Let rsi be the pointer to the current block of the output
    
rle_encode_loop_first_char_search:
    # If the current character is an incrorrect one, increase the %rdi
    movb (%rdi), %al
    
    cmpb $'+', %al
    je rle_encode_loop_char_continue
    cmpb $'-', %al
    je rle_encode_loop_char_continue
    cmpb $'.', %al
    je rle_encode_loop_char_continue
    cmpb $',', %al
    je rle_encode_loop_char_continue
    cmpb $'[', %al
    je rle_encode_loop_char_continue
    cmpb $']', %al
    je rle_encode_loop_char_continue
    cmpb $'<', %al
    je rle_encode_loop_char_continue
    cmpb $'>', %al
    je rle_encode_loop_char_continue
    
    # If none of the conditions met - just skip the currect character
    incq %rdi
    jmp rle_encode_loop_first_char_search
    
    # Now we will iterate over all the characters in the raw string
rle_encode_loop:
    # increase the character ptr %rdi
    incq %rdi
    movb (%rdi), %al
rle_encode_loop_char_continue:

    cmpb $'+', %al
    je rle_encode_loop_continue
    cmpb $'-', %al
    je rle_encode_loop_continue
    cmpb $'.', %al
    je rle_encode_loop_continue
    cmpb $',', %al
    je rle_encode_loop_continue
    cmpb $'[', %al
    je rle_encode_open_bracket
    cmpb $']', %al
    je rle_encode_closed_bracket
    cmpb $'<', %al
    je rle_encode_loop_continue
    cmpb $'>', %al
    je rle_encode_loop_continue
    cmpb $0, %al
    je rle_encode_loop_end
    
    # If none of the conditions met - just skip the currect character
    jmp rle_encode_loop
    
rle_encode_loop_continue:
    # Check whether the current character is the same as in the current block
    movb 4(%rsi), %bl
    cmpb %bl, %al
    jne rle_encode_loop_new_block # If not - create a new block
    # Otherwise increase the counter by one and continue
    incl (%rsi)
    jmp rle_encode_loop

rle_encode_loop_new_block:
    # Create a new block
    addq $8, %rsi
    movq $0, (%rsi)
    movb %al, 4(%rsi)
    movl $1, (%rsi)
    jmp rle_encode_loop


rle_encode_open_bracket:
    addq $8, %rsi # Add 8 to rsi so now it points directly to the bracket block
    
    # Setup current block
    movq $0, (%rsi)
    movb $'[', 4(%rsi)
    movl $1, (%rsi)

    # Save the current address of the block
    pushq %rsi

    # Allocate one additional quad after the current block
    addq $8, %rsi
    movq $0, (%rsi) # Clean it up
    
    # Create a new block
    jmp rle_encode_loop

rle_encode_closed_bracket:
    addq $8, %rsi # Add 8 to rsi so now it points directly to the bracket block
    
    # Setup current block
    movq $0, (%rsi)
    movb $']', 4(%rsi)
    movl $1, (%rsi)

    # Restore the address of the block
    popq %rdx
    
    # Put the current block address into the previously allocated block after open bracket
    movq %rsi, 8(%rdx)
    
    
    # Put the open bracket block address after current block
    addq $8, %rsi
    movq $0, (%rsi) # Clean it up
    movq %rdx, (%rsi)

    jmp rle_encode_loop


rle_encode_loop_end:
    # Add '$' as the last block
    addq $8, %rsi
    movq $0, (%rsi)
    movb $'$', 4(%rsi)
    movl $1, (%rsi)
    
    # Return the last address of the output, which is rsi + 8
    addq $8, %rsi
    movq %rsi, %rax

    popq %rbx
    movq %rbp, %rsp
    popq %rbp
    ret
    
