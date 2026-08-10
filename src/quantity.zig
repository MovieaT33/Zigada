const std = @import("std");

const RationalRegistry = @import("numeric/rational_registry.zig").RationalRegistry;
const UnitExpression = @import("unit/unit_expression.zig").UnitExpression;
const UnitRegistry = @import("unit/unit_registry.zig").UnitRegistry;

pub const Error = error{
    UnitMismatch,
};

pub fn Quantity(comptime T: type) type {
    return struct {
        const Self = @This();

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
            if (!a.expression.eql(b.expression.*))
                return error.UnitMismatch;

            return .{
                .value = try T.add(a.value, b.value),
                .expression = a.expression,
            };
        }

        pub fn sub(a: Self, b: Self) !Self {
            if (!a.expression.eql(b.expression.*))
                return error.UnitMismatch;

            return .{
                .value = try T.sub(a.value, b.value),
                .expression = a.expression,
            };
        }

        pub fn scale(a: Self, b: T.Type) !Self {
            return .{
                .value = try T.mul(a.value, b),
                .expression = a.expression,
            };
        }

        pub fn unscale(a: Self, b: T.Type) !Self {
            return .{
                .value = try T.div(a.value, b),
                .expression = a.expression,
            };
        }

        pub fn combine(
            a: Self,
            b: Self,
            comptime op: UnitExpression.Operation,
            name: ?[]const u8,
            comptime cross_cancellation: bool,
        ) !Self {
            const expression = try UnitExpression.combine(
                a.expression,
                b.expression,
                op,
                name,
                cross_cancellation,
            );

            const value = switch (op) {
                .mul => try T.mul(a.value, b.value),
                .div => try T.div(a.value, b.value),
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

            if (buffer) |_| {
                try self.value.writeValue(io, buffer.?);
            } else {
                try self.value.writeValue(io, undefined);
            }

            try stdout.writePositionalAll(io.*, " ", 0);

            try self.expression.writeUnits(io);

            try stdout.writePositionalAll(io.*, "\n", 0);
        }
    };
}
