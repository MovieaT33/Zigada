pub fn NumericWrapper(comptime T: type) type {
    comptime {
        switch (@typeInfo(T)) {
            .int, .float => {},
            else => @compileError("NumericWrapper requires an integer or float type"),
        }
    }

    return struct {
        pub const Type = T;

        pub fn add(a: T, b: T) T {
            return a + b;
        }

        pub fn sub(a: T, b: T) T {
            return a - b;
        }

        pub fn mul(a: T, b: T) T {
            return a * b;
        }

        pub fn div(a: T, b: T) T {
            return a / b;
        }
    };
}
