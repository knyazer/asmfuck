# Brainfuck compiler, optimized
/* vim: set filetype=gas : */
# TODO: advanced compiling, loop isolation, writing intermediate code representation into separate files
# TODO: testing suite
# TODO: do not use C libraries, use only system calls
# TODO: read https://www.agner.org/optimize/
# TODO: RLE compression optimization
# TODO: Make faster iterating when 0 encountered at loop start
# P.S. I am a bit scared about fraud, as there were some huge parts of the code generated by Copilot, and it seems like it stole it from some repo on github, as suggestion were really elaborate and precise.
.global brainfuck

.include "jumptable.s"
.include "compiler-gen.s"
.include "compiler-exec.s"
.include "rle.s"
.include "leaf-opt.s"

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
# $ - end of the pogram

brainfuck:
    # these two lines are for loading the argv and argc without stdlib
    #popq %rdi
    #movq %rsp, %rsi
    
    # Save registers
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    pushq %rbx
    pushq %rbx

    pushq %rbp              # Push base pointer to stack
    movq %rsp, %rbp         # Base pointer = stack pointer 

    subq $0x80000, %rsp    # Allocate 2 MB of memory on stack
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
    # --------------------------------------------------   <-  %rdi
    # end
    # 
    # --------------------------------------------------   <-  -48(%rbp)
    # compiled brainfuck code
    # --------------------------------------------------   <-  -40(%rbp)
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
    subq $30080, %rax     # 30064 = 30000 + 64, 64 is the size of the local vars block
    movq %rax, -24(%rbp)
    movq %rsp, -16(%rbp)
    
    # And here we are, now we have a brainfuck program lying in the end of the stack
    
    # Let's now compress the program, using RLE compression.

    # The block structure is as follows:
    # [4 bytes] - number of repetitions
    # [1 byte] - command
    # [3 bytes] - reserved (padding to 8 bytes)
    # rdi has not changed yet
    movq -16(%rbp), %rsi  # Pointer to the beginning of the rle compressed code
    call rle_encode
    movq %rax, -32(%rbp)  # Save the pointer to the end of the rle compressed code
    
#jmp NO_LO 
    # First parameter is the address of RLE compressed program
    movq -16(%rbp), %rdi
    call leaf_optimization
NO_LO:
#jmp NO_COMPILATION
    # Now lets compile the thingy
    # First of all, allocate a huuuge chunk of memory for the compiled code via malloc
    movq -32(%rbp), %rdi
    subq -16(%rbp), %rdi
    movq $24, %rax
    mulq %rdi
    movq %rax, %rdi
    addq $0x8000, %rdi
    call malloc
    movq %rax, -40(%rbp)  # Save the pointer to the beginning of the compiled code

    # rdi - address of first block, rsi - address of the output
    movq -16(%rbp), %rdi
    movq -40(%rbp), %rsi
    call compile_to_string
    movq %rax, -48(%rbp)  # Save the pointer to the end of the compiled code

    # Calculate the length of the string:
    movq -48(%rbp), %rsi
    movq -40(%rbp), %rax
    subq %rax, %rsi
    # First parameter is the address
    movq -40(%rbp), %rdi
    call compile_from_string

    # Check if the rax is 0, if so - exit
    cmpq $0, %rax
    je end
NO_COMPILATION:
    #movq $1, %rax           # Write flag
    #movq $1, %rdi           # stdout file descriptor
    #leaq -2000000(%rbp), %rsi         # pointer to the string
    #syscall

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

    # skip the output, because we don't need it for release
    # remove the next line if you want to look to the code
    jmp RLE_show_debug_end
    movq -16(%rbp), %rbx    # Store pointer to the current block in rbx, as it is callee saved
looping_around_for_RLE_printing:
    movq $0, %rax           # Printf flag, no SIMD
    movq $RLE_placeholder, %rdi # Printf format string
    movq $0, %rsi           # Zerofy the rsi register
    movl (%rbx), %esi       # Number of repetitions
    movq $0, %rdx           # Zerofy the rdx register
    movb 4(%rbx), %dl      # Command
    call printf

    cmpb $'[', 4(%rbx)
    je skip_next_block
    cmpb $']', 4(%rbx)
    je skip_next_block
    cmpb $'(', 4(%rbx)
    je skip_next_block
    cmpb $')', 4(%rbx)
    je skip_next_block

    jmp not_skip_next_block
skip_next_block:
    addq $8, %rbx
not_skip_next_block:
    addq $8, %rbx          # Move to the next block
    cmpq -32(%rbp), %rbx   # Check that we are not at the end of the RLE program
    jne looping_around_for_RLE_printing
    
    # Print delimiter
    movq $0, %rax
    movq $delimiter, %rdi
    call printf
RLE_show_debug_end:

    # Put brainfuck memory end at %r10
    movq %rbp, %r10
    subq $64, %r10

    # Zerofy brainfuck memory
    movq -24(%rbp), %rax
zerofy_memory:
    movq $0, (%rax)
    addq $8, %rax
    cmpq %rax, %r10 # Iterate until %rax == brainfuck memory end
    jne zerofy_memory

# And finally, start the interpretation
start_the_execution:
    movq -16(%rbp), %rbx    # Store pointer to the current block in rbx, as it is callee saved
    
    # Now, we can execute the program
    # Lets define some registers:
    # %r12 - pointer to the current instruction block
    # %r13 - brainfuck memory pointer
    # %r14 - number of repetitions for current optimized loop
    movq -16(%rbp), %r12
    movq -24(%rbp), %r13
    # subtract block size from r12, as we will be adding it in the loop
    subq $8, %r12
looping_around_for_execution:
    addq $8, %r12         # Move to the next block

    # Put the command into the r10 register, and pad it with zeros
    movzxb 4(%r12), %r10
    # GDB command to debug: printf "%ld %c, bmem value: %ld, bmem_ptr: %ld \n\n", $rdi, $r10, *(uint64_t*)$r13, $r13 - *(uint64_t*)($rbp-24)
    # Jump to the correct command
    shlq $3, %r10
    movq jumptable(%r10), %r10
    jmp *%r10
    
    # If we are here, then we failed somehow, but as it was not fatal, then just continue pretending nothing happened
    jmp looping_around_for_execution
    
    # Here are the definitions of complex brainfuck commands
bf_complex_start:
    addq $8, %r12 # Increment the instruction pointer anyways, so now it points to the loop end address
    movzxb (%r13), %r14 # Save the current data pointer to specific register
    cmpb $0, %r14b        # Check if the current memory cell is zero
    jne looping_around_for_execution # If not - continue execution
    movq (%r12), %r12
    addq $8, %r12 # Move the pointer to the instruction after the loop end
    jmp looping_around_for_execution # and continue execution

bf_complex_end:
    # nothing to do here
    jmp looping_around_for_execution

bf_complex_mul:
    movl (%r12), %edi
    # current_cell += counter * repetitions
    movq %rdi, %rax     # Move the number of repetitions to rax
    mul %r14          # Multiply it by the counter
    add %rax, (%r13)    # Add it to the current cell
    jmp looping_around_for_execution

bf_complex_sub_mul:
    movl (%r12), %edi
    # current_cell -= counter * repetitions
    movq %rdi, %rax     # Move the number of repetitions to rax
    mul %r14          # Multiply it by the counter
    sub %rax, (%r13)    # Subtract it from the current cell
    jmp looping_around_for_execution

bf_complex_zero:
    movb $0, (%r13)
    jmp looping_around_for_execution

bf_complex_single_mul:
    addb %r14b, (%r13)
    jmp looping_around_for_execution

bf_complex_sub_single_mul:
    subb %r14b, (%r13)
    jmp looping_around_for_execution

bf_complex_exit:
    jmp post_execution
    # Here are the definitions of normal brainfuck commands
bf_add:
    movl (%r12), %edi
    addb %dil, (%r13)
    jmp looping_around_for_execution
    
bf_sub:
    movl (%r12), %edi
    subb %dil, (%r13)
    jmp looping_around_for_execution

bf_right:
    movl (%r12), %edi
    addq %rdi, %r13
    jmp looping_around_for_execution

bf_left:
    movl (%r12), %edi
    subq %rdi, %r13
    jmp looping_around_for_execution

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

    jmp looping_around_for_execution
    
bf_read:
    # While it seems inadequate, our compressed version should be always the same as uncompressed, so we repeat reading char the required number of times. 
        
    # Counter is in %r15 (%edi to be exact), which we use, so move it to %r15
    movq $0, %r15
    movl (%r12), %r15d # Counter is the number of repetitions
bf_read_loop:
    movq $0, %rax           # Read flag
    movq $0, %rdi           # stdin file descriptor
    movq $1, %rdx           # max size
    subq $16, %rsp          # Allocate two bytes for temporary storage of the read value
    # when we read single byte, it is the char that we want to put into the memory
    movq %rsp, %rsi         # Address of the buffer
# TODO: correct reading of chars
    syscall
    movb (%rsp), %al      # Move the read value to the temporary register

    cmpb $0, %al           # Check if everything works as expected
    jl cannot_read_from_stdin # If there is an error, show error message and exit
    
    #cmpb $'\n', %al           # Check if we read a newline
    #je bf_read_loop           # If we did, then read again

    movb %al, (%r13)       # Load value from the temporary register to the brainfuck memory
    addq $16, %rsp          # Deallocate the temporary storage
    
    decq %r15               # Decrement the counter
    cmpq $0, %r15           # Check if we are done
    jne bf_read_loop        # If we have not read all the chars, then read the next one

    jmp looping_around_for_execution

bf_loop_start:
    addq $8, %r12 # Increment the instruction pointer anyways, so now it points to the loop end address
    cmpb $0, (%r13)         # Check if the current memory cell is zero
    jne looping_around_for_execution # If not - continue execution

    # If it is, we have pointer to the end block stored in the next cell
    movq (%r12), %r12
    addq $8, %r12 # Move the pointer to the instruction after the loop end
    jmp looping_around_for_execution # and continue execution

bf_loop_end:
    addq $8, %r12 # Increment the instruction pointer anyways, so now it points to the cell with loop start address
    cmpb $0, (%r13)         # Check if the current memory cell is zero
    je looping_around_for_execution # If it is, continue execution

    # If it is not, then we have pointer to the start loop block stored in the current cell, so move the pointer to it
    movq (%r12), %r12
    # and add 8 to it, so now it points to the instruction after the loop start
    addq $8, %r12
    jmp looping_around_for_execution # and continue execution
    
post_execution:
    # Clean up the stack
    jmp end

# Different variants of how we can exit

end:
    jmp end_brainfuck#call exit #syscall 

fail:
    jmp end_brainfuck#call exit #syscall

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

end_brainfuck:
    movq %rbp, %rsp
    popq %rbp
    popq %rbx
    popq %rbx
    popq %r12
    popq %r13
    popq %r14
    popq %r15
    ret
