1. **Imports** — sort imports using `zig build fix-imports`.
2. **Self** — use `Self` for references to the current struct type.
3. **Enums** — explicitly specify the underlying integer type.
4. **Function order** — order functions by role: lifecycle, copy/clone, queries, mutation, writers, conversion, then helpers.
5. **Line wrapping** — wrap long constructs when needed for readability.
6. **Functions** — handle all possible input variants and relevant edge cases.
7. **Functions** — limit functions to *35* lines, except in main.zig.
8. **Public** — use `pub` only for declarations that are part of the public API.
9. **Comments** — use comments only when code is unclear or explaining a large function.
