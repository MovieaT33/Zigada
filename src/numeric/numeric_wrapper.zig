const std = @import("std");

pub const Error = error{
    MissingBuffer,
};

pub fn NumericWrapper(comptime T: type) type {
    comptime {
        switch (@typeInfo(T)) {
            .int, .float => {},
            else => @compileError("NumericWrapper requires an integer or float type"),
        }
    }

    return struct {
        const Self = @This();

        pub const Type = Self;

        value: T,

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        pub fn deinit(_: *const Self) void {}

        pub fn add(a: Self, b: Self) !Self {
            return .{ .value = a.value + b.value };
        }

        pub fn sub(a: Self, b: Self) !Self {
            return .{ .value = a.value - b.value };
        }

        pub fn mul(a: Self, b: Self) !Self {
            return .{ .value = a.value * b.value };
        }

        pub fn div(a: Self, b: Self) !Self {
            return .{ .value = a.value / b.value };
        }

        pub fn writeValue(
            self: *const Self,
            io: *const std.Io,
            buffer: ?[]u8,
        ) !void {
            if (buffer == null) return error.MissingBuffer;

            const stdout = std.Io.File.stdout();

            const value = try std.fmt.bufPrint(
                buffer,
                "{}",
                .{self.value},
            );

            try stdout.writePositionalAll(io.*, value, 0);
        }
    };
}
