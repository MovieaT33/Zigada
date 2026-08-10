1. **Imports** — sort imports using `zig build fix-imports`.
2. **Self** — use Self for references to the enclosing struct type.
3. **Self** — don't introduce `Self` solely for one-off references.
3. **Enums** — explicitly specify the underlying integer type.
4. **Function order** — order functions by role: lifecycle, copy/clone, queries, mutation, writers, conversion, then helpers.
5. **Line wrapping** — wrap long constructs when needed for readability.
6. **Errors** — if a function can return only one error, explicitly specify that error in its return type.
7. **Functions** — handle all possible input variants and relevant edge cases.
8. **Functions** — limit functions to *35* lines, except in main.zig.
9. **Public** — use `pub` only for declarations that are part of the public API.
10. **Comments** — use comments only when code is unclear or explaining a large function.
