const std = @import("std");

const UnitExpression = @import("unit_expression.zig").UnitExpression;
const UnitRegistry = @import("unit_registry.zig").UnitRegistry;

pub const Error = error{
    UnitMismatch,
};

pub fn Quantity(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T.Type,
        expression: *UnitExpression,

        pub fn init(value: T.Type, expression: *UnitExpression) Self {
            return .{
                .value = value,
                .expression = expression,
            };
        }

        pub fn add(a: Self, b: Self) Error!Self {
            if (!a.expression.eql(b.expression.*))
                return error.UnitMismatch;

            return .{
                .value = T.add(a.value, b.value),
                .expression = a.expression,
            };
        }

        pub fn sub(a: Self, b: Self) Error!Self {
            if (!a.expression.eql(b.expression.*))
                return error.UnitMismatch;

            return .{
                .value = T.sub(a.value, b.value),
                .expression = a.expression,
            };
        }

        pub fn scale(a: Self, b: T) Self {
            return .{
                .value = T.mul(a.value, b),
                .expression = a.expression,
            };
        }

        pub fn unscale(a: Self, b: T) Self {
            return .{
                .value = T.div(a.value, b),
                .expression = a.expression,
            };
        }

        pub fn combine(
            a: Self,
            b: Self,
            comptime operation: UnitExpression.Operation,
            name: ?[]const u8,
            registry: *UnitRegistry,
            comptime cross_cancellation: bool,
        ) !Self {
            const expression = try UnitExpression.combine(
                a.expression,
                b.expression,
                operation,
                name,
                cross_cancellation,
            );

            const value = switch (operation) {
                .mul => T.mul(a.value, b.value),
                .div => T.div(a.value, b.value),
            };

            if (registry.find(expression.*)) |existing| {
                expression.deinit();

                return .{
                    .value = value,
                    .expression = existing,
                };
            }

            try registry.adopt(expression, false);

            return .{
                .value = value,
                .expression = expression,
            };
        }

        pub fn writeValue(
            self: *const Self,
            text: []u8,
            io: *const std.Io,
        ) !void {
            const stdout = std.Io.File.stdout();

            const value = try std.fmt.bufPrint(
                text,
                "{} ",
                .{self.value},
            );

            try stdout.writePositionalAll(io.*, value, 0);
        }

        pub fn write(
            self: *const Self,
            text: []u8,
            io: *const std.Io,
        ) !void {
            const stdout = std.Io.File.stdout();

            try self.writeValue(text, io);

            try self.expression.writeUnits(io);

            try stdout.writePositionalAll(io.*, "\n", 0);
        }
    };
}
