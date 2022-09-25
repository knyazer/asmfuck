# The leaf optimization thingy
/* vim: set filetype=gas : */
.text

# It takes as input RLE encoded data, and transforms it inplace into more efficient code

# First parameter is pointer to the start of RLE, second is pointer to the output
leaf_optimization:
    # Prologue
    pushq %rbp
    movq %rsp, %rbp

    # Push all the registers, just in case
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    # iterate over the whole code, and count the brackets.
    # At each closing bracket, check if the corresponding bracket has flag 'nlf' set. 'nlf' because 'not leaf'. 
    # If it is set, just continue like nothing happened
    # If it is not set, optimize the loop

    # Let's store pointer to the current block in RLE in r12
    movq %rdi, %r12
    movq %rsp, %r14
    
main_lo_loop:
    # Put the current symbol into rax
    movb 4(%r12), %r9b

    cmpb $'[', %r9b
    je lo_opening_bracket

    cmpb $']', %r9b
    je lo_closing_bracket

    cmpb $'$', %r9b
    je end_leaf_optimization

lo_condition_end:
    # If it is not a bracket, then just move to the next block
    addq $8, %r12

    # Repeat the loop
    jmp main_lo_loop

found_leaf:
    # Try to detect zeros
#    jmp zero_detection
#zero_detection_ret:
    
    # Count the arrows (total ptr change) in the loop
    # Simultaneously calculate the iteration step of the counter
    # Let the pointer to the inner-loop instruction be in rcx, as found leaf is called when the rcx points to the correct opening bracket.
    # Lets store the current pointer delta (arrow sum) in rbx, and the counter step in rdx
    movq %rcx, %r15 # Save the pointer to the opening bracket for future use
    movq $0, %rdx
    movq $0, %rbx
    addq $8, %rcx

lo_check_correctness_loop:
    # Check that we haven't reached the closing bracket yet
    cmpq %rcx, %r12
    je finish_checking_correctness  # If we have reached the end, break the loop

    # Save symbol in rax
    movb 4(%rcx), %al
    cmpb $'>', %al
    je lo_arrow_right
    cmpb $'<', %al
    je lo_arrow_left
    
    # If there is an input into the loop - do not optimize the loop
    cmpb $',', %al
    je lo_condition_end
    
    # If there is an output from the loop - do not optimize
    cmpb $'.', %al
    je lo_condition_end

    cmpq $0, %rbx   # Check that the arrow sum is zero
    je lo_arrow_sum_is_zero 

arrow_if_end:
    addq $8, %rcx
    jmp lo_check_correctness_loop

lo_arrow_right:
    addl (%rcx), %ebx
    jmp arrow_if_end

lo_arrow_left:
    subl (%rcx), %ebx
    jmp arrow_if_end

lo_arrow_sum_is_zero:
    cmpb $'+', %al
    je lo_plus
    cmpb $'-', %al
    je lo_minus
    jmp arrow_if_end

lo_plus:
    addl (%rcx), %edx
    jmp arrow_if_end

lo_minus:
    subl (%rcx), %edx
    jmp arrow_if_end


finish_checking_correctness:    
    cmpl $-1, %edx  # Check that the counter step is exactly -1
    jne lo_condition_end # If condition is not met -> end the optimization of the loop

    cmpl $0, %ebx    # Check that the arrow sum is zero
    jne lo_condition_end # If condition is not met -> end the optimization of the loop
    
    # If we are here, then we have a loop which can be optimized

    # The *optimization* routine is simple: we just replace brackets [] with parentheses (), + with *, - with /.    # Let's move the pointer to the [ in rax, and pointer to the ] in rbx
    movq %r15, %rax
    movq %r12, %rbx

# Replace some specific patterns with commands, currently only "!".
lo_replacement_pattern_detection:
    # Detect 0 patter: [-]:
    # Check that loop size = 1 (4 including brackets and pointer)
    movq %rax, %rcx
    addq $32, %rcx
    cmpq %rcx, %rbx
    jne lo_replacement_loop_prep # If the pattern length of loop is not 3, then just continue
    
    # Check that the only symbol in the loop is -
    movb 20(%rax), %cl # 12 because 4 is the offset, 16 is the after next block
    cmpb $'-', %cl
    jne lo_replacement_loop_prep # If the symbol is not -, then just continue

    # If all the conditions are met, then replace the loop with the command
    # replace [ with 0 and 1 repetetion
    movq $0, (%rax)
    movb $'!', 4(%rax)
    movl $1, (%rax)
    # replace -,] and pointers with empty blocks
    movq $0, 8(%rax)
    movq $0, 16(%rax)
    movq $0, 24(%rax)
    movq $0, 32(%rax)

    jmp finish_lo_replacement_loop

lo_replacement_loop_prep:
    # Not iterate over all the elements between the brackets, and replace them
    # rcx is the counter, again
    movq %rax, %rcx

lo_replacement_loop:
    # Check that we haven't reached the closing bracket yet    # Save symbol in r8
    movb 4(%rcx), %r8b
    cmpb $'[', %r8b
    je lo_replacement_opening_bracket
    cmpb $']', %r8b
    je lo_replacement_closing_bracket
    cmpb $'+', %r8b
    je lo_replacement_plus
    cmpb $'-', %r8b
    je lo_replacement_minus

lo_replacement_if_end:
    # Check if we need to exit the loop
    cmpq %rcx, %rbx
    je finish_lo_replacement_loop  # If we have reached the end, break the loop
    
    addq $8, %rcx
    jmp lo_replacement_loop


lo_replacement_opening_bracket:
    movb $'(', 4(%rcx)
    addq $8, %rcx
    jmp lo_replacement_if_end

lo_replacement_closing_bracket:
    movb $')', 4(%rcx)
    addq $8, %rcx
    jmp lo_replacement_if_end

lo_replacement_plus:
    cmpl $1, (%rcx)
    movb $'a', 4(%rcx)
    je lo_replacement_if_end
    
    movb $'*', 4(%rcx)
    jmp lo_replacement_if_end

lo_replacement_minus:
    cmpl $1, (%rcx)
    movb $'s', 4(%rcx)
    je lo_replacement_if_end

    movb $'/', 4(%rcx)
    jmp lo_replacement_if_end


finish_lo_replacement_loop:
    # Now we are probably entirely done with the loop
    jmp lo_condition_end



lo_opening_bracket:
    # Set the flag 'nlf' for all the parent brackets, until bracket with the flag encountered
    jmp set_stack_brackets_nlf_flag 
ret_ssbnf:
    # If it is an opening bracket, then push the pointer to it to the stack, twice for the stack to be aligned
    pushq %r12
    pushq %r12

    addq $8, %r12 # Skip the block with address
    jmp lo_condition_end


lo_closing_bracket:
    # If it is a closing bracket, we can check that the corresponding bracket flag just jumping to it, as pointer to the opening bracket is in the next cell
    addq $8, %r12 # Move to the next cell
    movq (%r12), %rcx # Load the pointer to the opening bracket
    # Check that 'nlf' flag is not set
    cmpb $0, 5(%rcx)
    je found_leaf   # If so jump to subroutine 'found_leaf'
    # otherwise, do nothing, and continue
    jmp lo_condition_end

set_stack_brackets_nlf_flag:
    # pointer to the current bracket is rsp
    # r8 will be iterator
    movq %rsp, %r8
ssbnf_loop:

    cmpq %r8, %r14     # if we are at the end of the brackets list, then we are done
    je end_ssbnf      # otherwise, continue setting

    # Load the address of the current bracket block into rdx
    movq (%r8), %rdx

    cmpb $1, 5(%rdx)    # $1 is nlf flag
    je end_ssbnf        # if it is set, then we are done
    
    # otherwise, set the flag and increase the counter by 16, as the values aligned to 16 bytes
    movb $1, 5(%rdx)
    addq $16, %r8
    
    jmp ssbnf_loop
end_ssbnf:
    jmp ret_ssbnf


end_leaf_optimization:
    # Set the rax to the pointer to the last block
    movq %r12, %rax

    # Epilogue
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    
    movq %rbp, %rsp
    popq %rbp

    ret
