.text
filename: .asciz "/tmp/test42"
message: .asciz "banana"
.global main
main:
    # Create a file using syscall GAS assembly
    movq $85, %rax
    movq $484, %rsi
    movq $filename, %rdi
    syscall

    movq %rax, %r12 # Save the file descriptor

    # Write to the file using syscall GAS assembly
    movq $1, %rax
    movq $5, %rdx
    movq %r12, %rdi
    movq $message, %rsi
    syscall
