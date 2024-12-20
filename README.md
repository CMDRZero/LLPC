# LLPC
LLPC is my own little project to compile a c like language into LASM, or LALU Assembly language. If you don't know what that is, this project probably isnt for you, but if you do and would like to help thats wonderful. A sample of what LLPC code might look like and depends on how it will be finalized is below.

```
using std;

static type int = u32;
static type char = u8;

char const [] msg = "Hello world!";

void main() {
    int sum = 2 + 2;
    assert sum == 4;
    std:println(msg);
}
```

Most of the various md file are for my own notes, but I'll clean that up as I work. Don't assume everything written is accurate unless I note it here.

### The Pipeline: 
LLPC is an imntermediate language between the theoretical LALUL and LASM, with the following chain being the order of compilation.

LALUL -> LLPC -> LLIR -> LASM \
With the rewrite of LASM to support the new v3 cpu design (Tentative name: LECU), LLIR is now deprecated, thus this project will integrate its own lowering convention.

### Stages:
Why not just document all my plans here?

Stage 0: Tokenization:
 * Done
 * May be revised as project continues

Stage 1: Parsing:
 * In-progress
 * To support Alpha Build, needs:
   * Struct declarations
   * Main function
   * Static Functions
   * All expression types
   * Ifs, Whiles (Dos), Fors, & Returns
 * Streach Goal: Inline assembly

Stage 2: Semantic Analysis:
 * Type inferencing
 * Use static information from Stage 1 (Struct declarations, etc)

Stage 3: HLIR:
 * Traverse program tree and emit High Level IR
 * Specs to be detirmined

Stage 4: SSA:
 * Convert HLIR into block based Static Single Assignment
 * Dissolve labels into generic ids
   * Store in debugger if possible
 * Perform static value optimization and dead code elimination

Stage 5: LLAR:
 * Convert SSA into multiple assignment Low Level Abstracted Representation
 * Basically just SSA but names can be reused

Stage 6: LLIR:
 * Expand typed operations into typeless operations on virtual registers
 * Use PENT format of CPU specs

Stage 7: LASM:
 * Perform register allocation and stack spilling as needed
 * Likely using a simple algorithm to start and moving to Graph Coloring if I have time

Stage 8: ALKBO:
 * Perform Assembly Level Known Bit Optimization by using bit structures and instruction vouching.
 * Remove unvouched instructions and inject immediates and precomputations

Stage 9: Final Linking:
 * Resovle any unliked values at this point (Pointers to labels or functions)

Stage 10: Assembly:
 * Call assembler on generated assembly file