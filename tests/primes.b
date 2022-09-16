generate comma
>++++[-<+++++++++++>]
generate all numbers from max to 2
>-[[->+>+<<]>[-<+>]+>-]<-<-<

[
  go to current number
  -<
  [
    number is not null: prime
    copy twice and print
    [->>+>>+<<<<]
    >>>>[>>>>++++++++++<<<<[->+>>+>-[<-]<[->>+<<<<[->>>+<<<]>]<<]>+[-<+>]>>>[-]>[-<<<<+>>>>]<<<<]<[>++++++[<++++++++>-]<-.[-]<]
    print comma
    <<<<[<<]<.>>>[>>]
    copy counter
    >[->+>>+<<<]>[-<+>]<

    for each cell
    <<<[
      move
      -<[->>+<<]>>>+
      go to counter and decrease then check if null
      [>>]+<-[>-]>[-
        reset last copied cell
        <<[<<]>[-]>[>>]
        reset counter
        >>[-<+<<+>>>]<[->+<]
      ]
      process next cell
      <<<[<<]<<
    ]
    move back all cells
    >>>>[<[-<<+>>]<+>>->>]
    clear counters
    <[-]>>>[-]<<<<<
  ]
  process next number
  <
]
