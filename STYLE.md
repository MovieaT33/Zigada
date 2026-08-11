# Naming

01. **Naming** — name things by what they represent, not their data structure.
02. **Shorthand** — use shorthand forms when possible.
03. **Clarity** — avoid ambiguous names; use descriptive names such as `index` instead of `i`, except for conventional mathematical variables or names whose meaning is clear from context.

# Imports

04. **Imports** — sort imports using `zig build fix-imports`.

# Visibility

05. **Public** — use `pub` only for declarations that are part of the public API.

# Enums

06. **Enums** — do not specify the underlying integer type.

# Formatting

07. **Line wrapping** — wrap long constructs when needed for readability.
08. **Single-statement control flow** — place a single statement on the next line without braces.

# Comments

09. **Comments** — comment only unclear code or large functions.

# Ordering

10. **Dependencies** — place dependencies before data.

# Structs

11. **Self** — use `Self` for the enclosing struct type.
12. **Self** — do not use `Self` for one-off references.
13. **Fields** — declare all fields together before methods.
14. **Initialization** — use multiline struct initialization only when the struct has more than one field.

# Functions

15. **Order** — order functions by role: lifecycle, copy/clone, queries, mutation, conversion, writers, helpers.
16. **Inline** — do not use `inline`.
17. **Length** — keep functions under *40* lines, except in `main.zig`.
18. **Input** — handle all input variants and relevant edge cases.
19. **Errors** — explicitly specify a function's only possible error.
20. **Error set** — define a public `Error` set only when custom errors are needed; use it instead of standalone `error.*`.
