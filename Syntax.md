# LLPC Syntax
Function Syntax

`[type]` `[name]` `(` `[args*]` `)` `{` `[body]` `}`

Where type is any valid type, or a tuple type of syntax `(` `[arg0, [arg1, ...]]` `)`

An example main function might be `void main() {...}`

An example tuple function might be `(u16, u1) AddWithCarry(u16 copy lhs, u16 rhs) {...}`

In LLPC, all args must be annotated after the type with `const`, `copy`, or `mut`. `const` implies no allowed mutation to the underlying data, `copy` creates a copy and allows mutation to the local copy, and `mut` doesnt copy, and allows mutation to the callers variable.