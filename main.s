# Brainfuck compiler, optimized
/* vim: set filetype=gas : */
# TODO: advanced compiling, loop isolation, writing intermediate code representation into separate files
# TODO: testing suite
# TODO: do not use C libraries, use only system calls
# TODO: read https://www.agner.org/optimize/
# TODO: RLE compression optimization
# TODO: Make faster iterating when 0 encountered at loop start
# P.S. I am a bit scared about fraud, as there were some huge parts of the code generated by Copilot, and it seems like it stole it from some repo on github, as suggestion were really elaborate and precise.

.include "jumptable.s"

.text

more_than_one_arg_message: .asciz "\n\033[1;31mError: Please, provide exactly one file to be executed. Think about your actions. \033[0m\n"

cannot_read_file_message: .asciz "\n\033[1;31mError: Cannot read specified file. Might be a TYPO, might be something else, idk. Check everything once more. \033[0m\n"

cannot_read_from_stdin_message: .asciz "\n\033[1;31mError: Cannot read from stdin. Probably something wrong with your system, or the program, or idk. I have not idea how to fix this. \033[0m\n"

nothing_in_stdin_message: .asciz "\n\033[1;31mError: Nothing in stdin. This might be caused by some random stuff in your terminal, so you could try to change terminal, or rerun the program. Other than that, I have no idea how to help you. \033[0m\n"

incomplete_loop_message: .asciz "\n\033[1;31mError: Incomplete loop in the compressed brainfuck code. Either you have a problem with you brainfuck code, or something went really wrong with the compression algorithm. This error means that at the '[' the data pointer had 0 value, so we started to search for loop closing statement ']', but encountered the end of code before finding any. Really bad error. \033[0m\n"

RLE_placeholder: .asciz "%ld%c"

char_placeholder: .asciz "%c"

found_a_leaf_message: .asciz "\n Found a leaf! \n"

int_placeholder: .asciz "%d->"

delimiter: .asciz "\n\n---------------------------\n\n"

test_text: .asciz "\n test - test \n"

.global _start

# The perfomace profiler I prefer is callgrind + kcachegrind
# The way you use them is to firstly run
# valgrind --tool=callgrind --dump-instr=yes --simulate-cache=yes --collect-jumps=yes ./main tests/mandelbrot.b
# and then
# kcachegrind callgrind.out.*
# then navigate to source code tab to the right, and there will be your assembly code with lr meaning percent of whole program time spent on this instruction, probably

# The benchmarking can be done via 
# time ./main tests/manelbrot.b
# the std is 0.25 seconds, so if your version differs by more than 0.8 seconds, that means your version is faster. if less - than it means it is the same. if it is slower by more than 0.8 seconds, that means your version is slower

# The list of operations:
# > - increment data pointer
# < - decrement data pointer
# + - increment value at data pointer
# - - decrement value at data pointer
# . - output value at data pointer
# , - input value at data pointer
# [ - jump to matching ] if value at data pointer is 0
# ] - jump to matching [ if value at data pointer is not 0
# ( - set mark to data pointer
# ) - set 0 to marked value
# ! - set 0 to value at data pointer
# * - add the marked value (multiplied by the number of repetetions) to value at data pointer
# / - subtract the marked value (multiplied by the number of repetitions) from value at data pointer
# a - add the marked value to value at data pointer only once
# s - subtract the marked value from value at data pointer only once
# A - add the marked value to value at data pointer exactly twice
# S - subtract the marked value from value at data pointer exactly twice

_start:
    # these two lines are for loading the argv and argc without stdlib
    popq %rdi
    movq %rsp, %rsi

    pushq %rbp              # Push base pointer to stack
    movq %rsp, %rbp         # Base pointer = stack pointer 
    
    subq $0x100000, %rsp    # Allocate 1 MB of memory on stack
    # The structure of stack is decently simple:
    # --------------------------------------------------   <- %rbp
    # some local vars & thingies
    # --------------------------------------------------   <-  -24(%rbp) + 30000 = %rbp - 64
    # brainfuck memory space (30 KiB)
    # --------------------------------------------------   <-  -24(%rbp)
    # empty space
    # --------------------------------------------------   <-  -32(%rbp)
    # RLE compressed brainfuck code 
    # block structure:
    # [4 bytes for number of reps]
    # [1 byte for command]
    # [3 byte for padding]
    # --------------------------------------------------   <-  -16(%rbp)
    # Raw brainfuck code (string)
    # --------------------------------------------------   <-  %rsp
    # end
    # 
    #
    # Some useful addresses:
    # -8(%rbp) - file descriptor
    # -16(%rbp) - pointer to the highest address with brainfuck code (end of the code)
    # -24(%rbp) - pointer to the lowest address of brainfuck memory space (beginning of it, size 30KiB)
    # -32(%rbp) - pointer to the highest address of the RLE compressed brainfuck code (end of it)
    # %rsp - pointer to the lowest address with brainfuck code (beginning of the code)
    
    # Setup brainfuck memory pointer, temporary register rax
    movq %rbp, %rax
    subq $30064, %rax     # 30064 = 30000 + 64, 64 is the size of the local vars block
    movq %rax, -24(%rbp)
    
    # Put brainfuck memory end at %r10
    movq %rbp, %r10
    subq $64, %r10

    # Zerofy brainfuck memory
zerofy_memory:
    movq $0, (%rax)
    addq $8, %rax
    cmpq %rax, %r10 # Iterate until %rax == brainfuck memory end
    jne zerofy_memory


    # Check that there is exactly one argument (argc = 2, first one is something like path or number, whatever)
    cmpq $2, %rdi
    jne more_than_one_arg

    # Read the file
    movq 8(%rsi), %rdi  # 8(%rsi) is the second argv, which is the first argument provided, which is filename
    movq $2, %rax       # Open flag
    movq $0, %rsi       # Read only mode probably, idk
    syscall

    movq %rax, -8(%rbp)     # Save file descriptor to local variable

    # Read the file
    # Temporary store the pointer to the current brainfuck code end in the %r8
    movq %rsp, %r8

read_block:
    movq $128, %rdx         # Size of block to read
    movq $0, %rax           # Read flag
    movq -8(%rbp), %rdi     # File descriptor
    movq %r8, %rsi         # Address of the buffer
    syscall

    addq %rax, %r8          # Update the brainfuck code end pointer
    cmp $0, %rax            # Check if the file is over
    jl cannot_read_file    # if rax < 0, then syscall failed, and we want to show this #!DEBUG
    jne read_block          # If not, read another block

    # If it is, then save the pointer to the end of the brainfuck code
    movq %r8, -16(%rbp)
    
    # And here we are, now we have a brainfuck program lying in the end of the stack
    
    # Let's now compress the program, using RLE compression.

    # The block structure is as follows:
    # [4 bytes] - number of repetitions
    # [1 byte] - command
    # [3 bytes] - reserved (padding to 8 bytes)
    
    # Lets store current compressed program pointer in the %r8, and current raw program pointer in the %r9
    # %r8 is already set to the correct value, so set only %r9
    movq %rsp, %r9
    
add_new_block:
    # Copy the raw command to the compressed program
    movb (%r9), %r10b
    
    # Allow only correct brainfuck symbold
    cmpb $'+', %r10b            
    je not_skip_instruction
    cmpb $'-', %r10b
    je not_skip_instruction
    cmpb $'<', %r10b
    je not_skip_instruction
    cmpb $'>', %r10b
    je not_skip_instruction
    cmpb $'.', %r10b
    je not_skip_instruction
    cmpb $',', %r10b
    je not_skip_instruction
    cmpb $'[', %r10b
    je not_skip_instruction
    cmpb $']', %r10b
    je not_skip_instruction

    # If we are here, then we want to skip instruction
    addq $1, %r9
    cmpq -16(%rbp), %r9     # Check if we are at the end of the raw program
    je finish_RLE           # If we are, then finish the compression
    
    jmp add_new_block   # otherwise - skip the instruction and continue

not_skip_instruction:
    movq $0, (%r8)            # Clear the value of the first block
    movb %r10b, 4(%r8)

move_raw_pointer:
    incl (%r8)             # Increment the number of repetitions
    inc %r9                 # Move to the next raw command

restore_state_from_bad_command:
    movb (%r9), %r10b       # Save the current command to temporary register
    cmpq -16(%rbp), %r9     # Check if we are at the end of the raw program
    je finish_RLE           # If we are, then finish the compression
    
    # We want to have only singular [ or ] in the blocks of compressed program, as it makes readability better, and execution much less complicated, though overall almost not affecting anything else
    #jmp RLE_loop_last_step

    cmpb $'[', %r10b        # Check if the current command is [
    je RLE_loop_last_step        # If it was, then move to the next block, ignoring repetitions
    
    cmpb $']', %r10b        # Check if the current command is ]
    je RLE_loop_last_step        # If it was, then move to the next block, ignoring repetitions
    # If we encounter any symbol which is not command - just skip it

    cmpb $'+', %r10b            
    je continue_normally
    cmpb $'-', %r10b
    je continue_normally
    cmpb $'<', %r10b
    je continue_normally
    cmpb $'>', %r10b
    je continue_normally
    cmpb $'.', %r10b
    je continue_normally
    cmpb $',', %r10b
    je continue_normally

    # If we are here, then the command is incorrect, so we want to inrease the counter,
    inc %r9
    jmp restore_state_from_bad_command

continue_normally:
    cmpb 4(%r8), %r10b      # Otherwise, compare the current command with the previous one
    je move_raw_pointer     # If they are the same, then move to the next one

RLE_loop_last_step:
    # If they are not, then we need to add new block
    addq $8, %r8
    jmp add_new_block

finish_RLE:
    # Firstly, align the last pointer properly 
    addq $8, %r8
    # Save the current RLE program end pointer to the stack
    movq %r8, -32(%rbp)

    # Now, we have the RLE compressed program lying in the stack, and we can print it, for debugging purposes
    
    movq -16(%rbp), %rbx    # Store pointer to the current block in rbx, as it is callee saved

    #jmp start_the_execution
    
#looping_around_for_RLE_printing:
#    movq $0, %rax           # Printf flag, no SIMD
#    movq $RLE_placeholder, %rdi # Printf format string
#    movq $0, %rsi           # Zerofy the rsi register
#    movl (%rbx), %esi       # Number of repetitions
#    movq $0, %rdx           # Zerofy the rdx register
#    movb 4(%rbx), %dl      # Command
#    call printf
#    
#    addq $8, %rbx          # Move to the next block
#    cmpq -32(%rbp), %rbx   # Check that we are not at the end of the RLE program
#    jne looping_around_for_RLE_printing
#    
#    # Print delimiter
#    movq $0, %rax
#    movq $delimiter, %rdi
#    call printf

# Now, here is the most complex part of the program: loop optimization
# The idea is decently simple: the majority of the time spent in the program is in the loops, so we want to optimize them as much as possible. 
# The idea is to move the plus-minus instructions outside of the loop
# For example, here is a simple loop of moving value from one cell to another:
# [->+<]
# We want to move the + outside of the loop, so it will look like this:
# counter = *0
# *1 += counter
# *0 = 0
# There are some important properties that must be met:
# 1. Counter is in the same place always. This could be checked by counting all the arrows in the loop, and if their sum is 0, then the counter is in the same location. 
# 2. No nested loops, as loops allow arbitrary pointer movement, and we cannot predict where the counter will be after the iteration.
# 3. No input in the loop, as input introduces uncertainty.
# 4. Only single decrement of the loop counter. Otherwise - weird things could happend, so we don't want to deal with them (like overflow properties are not clearly defined, etc).
# That is all. Also, the interesting fact is that we can optimize loops partially:
# Consider the loop [->+<] again. We can unpack the loop using following technique:
# (/>*<)
# \ equivalent to *ptr -= *(value when passing closest parentheses behind)
# * equivalent to *ptr += *(value when passing closest parentheses behind)
# ) set value at the corresponding parentheses to 0
# Now, suppose we have nested loops:
# We apply optimization to the bottommost loop [->+(/>*<)<]
# It works fine, but can we apply optimization to the parent loop? I think that we can, but it is complicated. 
# Probably we can isolate parts which do not depend on the memory state from the dependent ones(actually, only () and [])
# Some other notes: if we encounter loop [-] we can quickly replace it to just set 0, as it is a common alogrithm in the brainfuck code. Use 0 instruction then
# 0 instruction is allowed to be optimized. Setting the variable to 0 do not introduce any dependency on data, so it completely fine to use it. The optimized version of 0 instruction is same 0, which means that efficient brainfuck programs will not ever do that. Indeed, while to reset variable to 0 in the loop, if after the first iteration it will be already resat? However, just in case, include 0 instruction. 
### IMP: the 0 instruction is denoted by '!' to be consistent with RLE representation


# Some thoughts:
# The optimization of this sort can be considered basic, as they use the fact that the things inside brainfuck loop do not depend on the memory state at all.
# So, whatever is inside the loop, it does not have any dependency on the previous iteration, thus we should be able to apply 'perfect' parallelization to it.
# In case of basic instructions (standart brainfuck syntax), we can parallelize them with multiplication. The problems start from this point, as 
# the loops which has nested 'optimized' loop inside them introduce a data dependency: indeed, loops are dependent on its corresponding counter.
# Now we have a problem: how to parallelize loops with data dependency?
# Suppose we have a loop [ first-instr-block (optimized-loop) second-instr-block ]. (there are no loops of any kind in the instruction blocks).
# We can parallelize the basic-syntax-instructions, but what about the optimized-loop?
# Lets ignore it for now, and focus on the optimization of partially-optimizable loops, like provided in the example above. 
# The representation would be: optimized(first-instr-block) [ X ] optimized(second-instr-block)
# In X we want to include all operations happening with the location corresponding to the counter of the nested loop. 
# This allows as to move second block to the beginning, as the instructions from there do not affect the counter, and we can move them outside of the loop.
# Now the structure is: optimized(first-instr-block) optimized(second-instr-block) [ first-ops-with-the-X-counter X last-ops-with-the-X-counter this-loop-counter-change ] . 
# IMPORTANT: Condition: the only operation made on the parent loop counter is single decrement.

# This stage of optimization of the not nested loops is called leaf optimization, as these loops in the tree of loops are the leaves.
leaf_optimization:
    # iterate over the whole code, and count the brackets.
    # At each closing bracket, check if the corresponding bracket has flag 'nlf' set. 'nlf' because 'not leaf'. 
    # If it is set, then we have a loop which can be optimized, and for now just print something, and set the flag 'nlf' for all the brackets in the stack
    # If it is set, just continue like nothing happened
    
    # Let's store pointer to the current block in RLE in r12, and pointer to the block in LO in r13
    movq -16(%rbp), %r12
    movq -40(%rbp), %r13
    
    # Store current stack pointer in r14, as the brackets data will lie between this value and rsp:
    # [ r14           ]
    # [ brackets data ]
    # [ rsp           ]
    movq %rsp, %r14

main_lo_loop:
    # Put the current symbol into rax
    movb 4(%r12), %r9b
    
    cmpb $'[', %r9b
    je lo_opening_bracket

    cmpb $']', %r9b
    je lo_closing_bracket

lo_condition_end:

    # If it is not a bracket, then just move to the next block
    addq $8, %r12

    # Check if we are not at the end of the RLE program
    cmpq -32(%rbp), %r12
    jne main_lo_loop

    # otherwise, we are done with leaf optimization, so lets start the execution
    jmp start_the_execution


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
    # Check that loop size = 1 (3 including brackets)
    movq %rax, %rcx
    addq $16, %rcx
    cmpq %rcx, %rbx
    jne lo_replacement_loop_prep # If the pattern length of loop is not 3, then just continue
    
    # Check that the only symbol in the loop is -
    movb 12(%rax), %cl # 12 because 4 is the offset and 8 is the next block
    cmpb $'-', %cl
    jne lo_replacement_loop_prep # If the symbol is not -, then just continue

    # If all the conditions are met, then replace the loop with the command
    # replace [ with 0 and 1 repetetion
    movb $'!', 4(%rax)
    movl $1, (%rax)
    # replace - and ] with empty blocks
    movq $0, 8(%rax)
    movq $0, 16(%rax)


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
    jmp lo_replacement_if_end

lo_replacement_closing_bracket:
    movb $')', 4(%rcx)
    jmp lo_replacement_if_end

lo_replacement_plus:
    cmpl $1, (%rcx)
    movb $'a', 4(%rcx)
    je lo_replacement_if_end
    
    cmpl $2, (%rcx)
    movb $'A', 4(%rcx)
    je lo_replacement_if_end

    movb $'*', 4(%rcx)
    jmp lo_replacement_if_end

lo_replacement_minus:
    cmpl $1, (%rcx)
    movb $'s', 4(%rcx)
    je lo_replacement_if_end

    cmpl $2, (%rcx)
    movb $'S', 4(%rcx)
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
    jmp lo_condition_end


lo_closing_bracket:
    # If it is a closing bracket, then pop the pointer to the opening bracket from the stack
    popq %rcx
    popq %rcx
    
    # Check that 'nlf' flag is not set
    cmpb $0, 5(%rcx)
    je found_leaf   # If so jump to subroutine 'found_leaf'
    # otherwise, do nothing, and continue
    jmp lo_condition_end

set_stack_brackets_nlf_flag:
    # pointer to the current bracket in rcx
    movq %rsp, %rcx
ssbnf_loop:

    cmpq %r14, %rcx     # if we are at the end of the brackets list, then we are done
    je end_ssbnf      # otherwise, continue setting

    # Load the address of the current bracket block into rdx
    movq (%rcx), %rdx

    cmpb $1, 5(%rdx)    # $1 is nlf flag
    je end_ssbnf        # if it is set, then we are done
    
    # otherwise, set the flag and increase the counter by 16, as the values aligned to 16 bytes
    movb $1, 5(%rdx)
    addq $16, %rcx
    
    jmp ssbnf_loop
end_ssbnf:
    jmp ret_ssbnf




start_the_execution:
    # Now we can print the processed RLE once more
    movq -16(%rbp), %rbx    # Store pointer to the current block in rbx, as it is callee saved
    
#looping_around_for_RLE_printing_2:
#    cmpb $0, (%rbx)     # Check if the block is empty
#    je after_printf_RLE_2
#    movq $0, %rax           # Printf flag, no SIMD
#    movq $RLE_placeholder, %rdi # Printf format string
#    movq $0, %rsi           # Zerofy the rsi register
#    movl (%rbx), %esi       # Number of repetitions
#    movq $0, %rdx           # Zerofy the rdx register
#    movb 4(%rbx), %dl      # Command
#    call printf
#after_printf_RLE_2:
#    addq $8, %rbx          # Move to the next block
#    cmpq -32(%rbp), %rbx   # Check that we are not at the end of the RLE program
#    jne looping_around_for_RLE_printing_2
#    
#    # Print delimiter
#    movq $0, %rax
#    movq $delimiter, %rdi
#    call printf


    # Now, we can execute the program
    # Lets define some registers:
    # %r12 - pointer to the current instruction block
    # %r13 - brainfuck memory pointer
    # %r14 - number of repetitions for current optimized loop
    movq -16(%rbp), %r12
    movq -24(%rbp), %r13
    # zerofi temprorary registers
    
looping_around_for_execution:
    # Put the command into the r10 register, and pad it with zeros
    movzxb 4(%r12), %r10
    # GDB command to debug: printf "%ld %c, bmem value: %ld, bmem_ptr: %ld \n\n", $rdi, $r10, *(uint64_t*)$r13, $r13 - *(uint64_t*)($rbp-24)
    # Jump to the correct command
    shlq $3, %r10
    movq jumptable(%r10), %r10
    jmp *%r10
    
    # If we are here, then we failed somehow, but as it was not fatal, then just continue pretending nothing happened
    jmp if_else_end_for_execution
    
    # Here are the definitions of complex brainfuck commands
bf_complex_start:
    movzxb (%r13), %r14 # Save the current data pointer to specific register
    jmp if_else_end_for_execution

bf_complex_end:
    # nothing to do here
    jmp if_else_end_for_execution

bf_complex_mul:
    movl (%r12), %edi
    # current_cell += counter * repetitions
    movq %rdi, %rax     # Move the number of repetitions to rax
    mul %r14          # Multiply it by the counter
    add %rax, (%r13)    # Add it to the current cell
    jmp if_else_end_for_execution

bf_complex_sub_mul:
    movl (%r12), %edi
    # current_cell -= counter * repetitions
    movq %rdi, %rax     # Move the number of repetitions to rax
    mul %r14          # Multiply it by the counter
    sub %rax, (%r13)    # Subtract it from the current cell
    jmp if_else_end_for_execution

bf_complex_zero:
    movb $0, (%r13)
    jmp if_else_end_for_execution

bf_complex_single_mul:
    addb %r14b, (%r13)
    jmp if_else_end_for_execution

bf_complex_double_mul:
    addb %r14b, (%r13)
    addb %r14b, (%r13)
    jmp if_else_end_for_execution

bf_complex_sub_single_mul:
    subb %r14b, (%r13)
    jmp if_else_end_for_execution

bf_complex_sub_double_mul:
    subb %r14b, (%r13)
    subb %r14b, (%r13)
    jmp if_else_end_for_execution

    # Here are the definitions of normal brainfuck commands
bf_add:
    movl (%r12), %edi
    addb %dil, (%r13)
    jmp if_else_end_for_execution
    
bf_sub:
    movl (%r12), %edi
    subb %dil, (%r13)
    jmp if_else_end_for_execution

bf_right:
    movl (%r12), %edi
    addq %rdi, %r13
    jmp if_else_end_for_execution

bf_left:
    movl (%r12), %edi
    subq %rdi, %r13
    jmp if_else_end_for_execution

bf_print:
    movq $0, %r15
    movl (%r12), %r15d # Counter is the number of repetitions
bf_print_loop:
    # Printf corrupts, but we kinda do not care, as all important things are callee saved
    
    movq $1, %rax           # Write flag
    movq $1, %rdi           # stdout file descriptor
    movq $1, %rdx           # Write one byte
    subq $16, %rsp          # Allocate two bytes for temporary storage of the read value
    movq $0, (%rsp)         # zerofy the temporary storage
    movq $0, 8(%rsp)        # zerofy the temporary storage
    movb (%r13), %cl       # value to temp
    movb %cl, (%rsp)       # char to show
    movq %rsp, %rsi         # pointer to the string
    syscall
    addq $16, %rsp          # Deallocate the temporary storage

    # when we read something the first char is what we need, and the second one is \n which we ignore
    movq %rsp, %rsi         # Address of the buffer
    decq %r15
    cmp $0, %r15
    jne bf_print_loop

    jmp if_else_end_for_execution
    
bf_read:
    # While it seems inadequate, our compressed version should be always the same as uncompressed, so we repeat reading char the required number of times. 
        
    # Counter is in %r15 (%edi to be exact), which we use, so move it to %r15
    movq $0, %r15
    movl (%r12), %r15d # Counter is the number of repetitions
bf_read_loop:
    movq $0, %rax           # Read flag
    movq $0, %rdi           # stdin file descriptor
    movq $2, %rdx           # max size
    subq $16, %rsp          # Allocate two bytes for temporary storage of the read value
    # when we read something the first char is what we need, and the second one is \n which we ignore
    movq %rsp, %rsi         # Address of the buffer

    syscall
    
    movb (%rsp), %al      # Move the read value to the temporary register
    movb %al, (%r13)       # Load value from the temporary register to the brainfuck memory
    addq $16, %rsp          # Deallocate the temporary storage
    
    cmpq $0, %rax           # Check if everything works as expected
    jl cannot_read_from_stdin # If there is an error, show error message and exit
    je nothing_in_stdin     # If there is nothing in stdin, show error message and exit (hmm?)
    
    decq %r15               # Decrement the counter
    cmpq $0, %r15           # Check if we are done
    jne bf_read_loop        # If we have not read all the chars, then read the next one

    jmp if_else_end_for_execution

bf_loop_start:
    cmpb $0, (%r13)         # Check if the current memory cell is zero
    je bf_jump_to_loop_end_start   # If it is, iterate to the end of the loop without executing anything
    subq $16 ,%rsp
    movq %r12, (%rsp)       # Save the current instruction pointer
    jmp if_else_end_for_execution # and continue execution

bf_loop_end:
    cmpb $0, (%r13)         # Check if the current memory cell is zero
    je pop_the_pointer_to_the_loop_start # If it is, then pop the pointer and continue main loop
    movq (%rsp), %r12               # If it is not, then set current instruction pointer to the saved one
    jmp if_else_end_for_execution # and continue execution
    
pop_the_pointer_to_the_loop_start:
    addq $16, %rsp
    jmp if_else_end_for_execution

# Here is the code for searching the corresponding closing bracket
bf_jump_to_loop_end_start:
    # The preparation step is to set %r15, which is a counter for brackets, to 1 (as it is single opening bracket)
    movq $1, %r15
bf_jump_to_loop_end:
    addq $8, %r12           # Move to the next block
        
    ### DEBUG! ###
    cmpq -32(%rbp), %r12    # Check if we are at the end of the program
    je incomplete_loop      # If we are, then something is really wrong -> show error message
    ### DEBUG! ###

    # Count all the brackets, when the sum is 0 - we found the end of the loop
    cmpb $']', 4(%r12) 
    je brackets_counter_dec
    cmpb $'[', 4(%r12)
    je brackets_counter_inc
        
    # If we are here, the current block is not a bracket, so repeat the cycle
    jmp bf_jump_to_loop_end

brackets_counter_dec:
    decq %r15
    jmp bf_jump_to_loop_end_sum_check

brackets_counter_inc:
    incq %r15
    jmp bf_jump_to_loop_end_sum_check

bf_jump_to_loop_end_sum_check:
    cmpq $0, %r15          # Check if the sum is 0, if so - we have found the end of the loop, ignoring all nested
    jne bf_jump_to_loop_end # If it is not, then continue searching
    jmp if_else_end_for_execution # If it is, then continue execution (to the next block, so ignore the close loop command)
    jmp if_else_end_for_execution # If it is, then continue execution (to the next block, so ignore the close loop command)
    
### IMPORTANT ###
# Design decision for loops is that we store pointers to the opening brackets in the stack, pushing them to it and popping from it. 
# This allows to quickly jump back and forth between the brackets, and also allows to have nested loops.

if_else_end_for_execution:
    addq $8, %r12         # Move to the next block
    cmpq -32(%rbp), %r12   # Check if we are at the end of the program
    jne looping_around_for_execution # If not, then continue to the next block

    # If we are at the end of RLE compressed brainfuck code, then we are done

    # Clean up the stack
    movq %rbp, %rsp
    popq %rbp

    jmp end

# Different variants of how we can exit

end:
    mov     $60, %rax               # system call 60 is exit
    movq $0, %rdi              # we want return code 0
    syscall 

fail:
    movq $1, %rdi
    mov $60, %rax
    syscall

# Some error messages
# Remove the first jmp to see them
more_than_one_arg:
    movq $1, %rax           # Write flag
    movq $1, %rdi           # stdout file descriptor
    movq $50, %rdx           # Write many bytes
    movq $more_than_one_arg_message, %rsi         # pointer to the string
    syscall

    jmp fail

cannot_read_file:
    movq $1, %rax           # Write flag
    movq $1, %rdi           # stdout file descriptor
    movq $50, %rdx           # Write many bytes
    movq $cannot_read_file_message, %rsi         # pointer to the string
    syscall

    jmp fail

cannot_read_from_stdin:
    movq $1, %rax           # Write flag
    movq $1, %rdi           # stdout file descriptor
    movq $50, %rdx           # Write many bytes
    movq $cannot_read_from_stdin_message, %rsi         # pointer to the string
    syscall

    jmp fail

nothing_in_stdin:
    movq $1, %rax           # Write flag
    movq $1, %rdi           # stdout file descriptor
    movq $50, %rdx           # Write many bytes
    movq $nothing_in_stdin_message, %rsi         # pointer to the string
    syscall

    jmp fail

incomplete_loop:
    movq $1, %rax           # Write flag
    movq $1, %rdi           # stdout file descriptor
    movq $50, %rdx           # Write many bytes
    movq $incomplete_loop_message, %rsi         # pointer to the string
    syscall

    jmp fail

### NOT USED ###

# Example of how to use system calls to print something
print_without_c:
    mov     $1, %rax                # system call 1 is write
    mov     $1, %rdi                # file handle 1 is stdout
    mov     $test_text, %rsi          # address of string to output
    mov     $13, %rdx               # number of bytes
    syscall   
