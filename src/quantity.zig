// Checked style

const std = @import("std");

const RationalRegistry = @import("numeric/rational_registry.zig").RationalRegistry;
const UnitExpression = @import("unit/unit_expression.zig").UnitExpression;
const UnitRegistry = @import("unit/unit_registry.zig").UnitRegistry;

pub fn Quantity(comptime T: type) type {
    return struct {
        const Self = @This();

        const BinaryOperation = enum {
            add,
            sub,
        };

        const ScaleOperation = enum {
            mul,
            div,
        };

        pub const Type = T;

        pub var unit_registry: *UnitRegistry = undefined;
        pub var rational_registry: ?*RationalRegistry = undefined;

        value: T.Type,
        expression: *UnitExpression,

        pub fn init(value: T.Type, expression: *UnitExpression) Self {
            return .{
                .value = value,
                .expression = expression,
            };
        }

        pub fn deinit(self: *Self) void {
            T.deinit(&self.value);
        }

        pub fn add(a: Self, b: Self) !Self {
            return binary(a, b, .add);
        }

        pub fn sub(a: Self, b: Self) !Self {
            return binary(a, b, .sub);
        }

        pub fn scale(quantity: Self, factor: T.Type) !Self {
            return scaleValue(quantity, factor, .mul);
        }

        pub fn unscale(quantity: Self, factor: T.Type) !Self {
            return scaleValue(quantity, factor, .div);
        }

        pub fn mul(
            a: Self,
            b: Self,
            name: ?[]const u8,
            comptime cross_cancellation: bool,
        ) !Self {
            return combine(
                a,
                b,
                .mul,
                name,
                cross_cancellation,
            );
        }

        pub fn div(
            a: Self,
            b: Self,
            name: ?[]const u8,
            comptime cross_cancellation: bool,
        ) !Self {
            return combine(
                a,
                b,
                .div,
                name,
                cross_cancellation,
            );
        }

        pub fn write(
            self: *const Self,
            io: *const std.Io,
            buffer: ?[]u8,
        ) !void {
            const stdout = std.Io.File.stdout();

            if (buffer) |buf| {
                try self.value.writeValue(io, buf);
            } else {
                try self.value.writeValue(io, undefined);
            }

            try stdout.writePositionalAll(io.*, " ", 0);
            try self.expression.writeUnits(io);
            try stdout.writePositionalAll(io.*, "\n", 0);
        }

        fn binary(
            left: Self,
            right: Self,
            comptime operation: BinaryOperation,
        ) !Self {
            if (!left.expression.eql(right.expression.*))
                return error.UnitMismatch;

            const value: T = switch (operation) {
                .add => try .add(left.value, right.value),
                .sub => try .sub(left.value, right.value),
            };

            if (rational_registry) |registry|
                try registry.adopt(value);

            return .{
                .value = value,
                .expression = left.expression,
            };
        }

        fn scaleValue(
            quantity: Self,
            factor: T.Type,
            comptime operation: ScaleOperation,
        ) !Self {
            const value: T = switch (operation) {
                .mul => try .mul(quantity.value, factor),
                .div => try .div(quantity.value, factor),
            };

            if (rational_registry) |registry|
                try registry.adopt(value);

            return .{
                .value = value,
                .expression = quantity.expression,
            };
        }

        fn combine(
            left: Self,
            right: Self,
            comptime operation: UnitExpression.Operation,
            name: ?[]const u8,
            comptime cross_cancellation: bool,
        ) !Self {
            const expression = try UnitExpression.combine(
                left.expression,
                right.expression,
                operation,
                name,
                cross_cancellation,
            );

            const value = switch (operation) {
                .mul => try T.mul(left.value, right.value),
                .div => try T.div(left.value, right.value),
            };

            if (unit_registry.find(expression.*)) |existing| {
                expression.deinit();

                return .{
                    .value = value,
                    .expression = existing,
                };
            }

            try unit_registry.adopt(expression, false);

            if (rational_registry) |registry|
                try registry.adopt(value);

            return .{
                .value = value,
                .expression = expression,
            };
        }
    };
}
