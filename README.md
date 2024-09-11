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