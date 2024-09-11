# LLPC
LLPC is my own little project to compile a c like language into LASM, or LALU Assembly language. If you don't know what that is, this project probably isnt for you, but if you do and would like to help thats wonderful. A sample of what LLPC code might look like and depends on how it will be finalized is below.

```
using std;

type const int = u32;
type const char = u8;

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
The LLPC to LLIR compiler is this project and the LLIR to LASM project is in a seperate repo (but will eventually be merged here). LALUL to LLPC is a streach goal.