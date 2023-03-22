# ASMF*ck!
Brainf*ck JIT-compiler/interpreter written in GAS assembly for linux.

Uses RLE, loop compression, pointer extraction and a bunch of other optimization techniques, which allow to reach comparable to SOTA performance! 

Interestingly, the most effective optimization is to compile brainf*uck into assembly, and then execute it -> allowed to speed up execution up to 10 times!

In the future we will add SIMD, multiprocessing and maybe something else. Stay tuned!

The majority of brainf*ck sample codes located in ```tests``` are stolen from http://esoteric.sange.fi/ , and I'm not sure about the type of license they use, so I just let you know that these code files aren't mine and blah-blah-blah.
