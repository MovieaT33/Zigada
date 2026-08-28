const std = @import("std");

const config = @import("../config.zig");
const ArithmeticOperation = @import("../arithmetic_operation.zig").ArithmeticOperation;
const UnitDefinition = @import("../unit/unit_definition.zig").UnitDefinition;
const QuantityRegistry = @import("quantity_registry.zig").QuantityRegistry;

const Allocator = std.mem.Allocator;

pub fn Quantity(comptime Numeric: type) type {
    const NumericDefinition = UnitDefinition(Numeric);
    const Constraint = UnitDefinition(Numeric).Constraint;

    return struct {
        const Self = @This();

        pub var allocator: ?Allocator = null;
        pub var quantity_registry: ?*QuantityRegistry(Self) = null;

        value: *const Numeric,
        definition: *const NumericDefinition,
        label: ?[]const u8,

        pub fn init(
            value: *const Numeric,
            definition: *const NumericDefinition,
            label: ?[]const u8,
        ) !*Self {
            const _allocator = getAllocator();

            try definition.constraint.validate(value);

            const self = try _allocator.create(Self);
            errdefer _allocator.destroy(self);

            self.* = .{
                .value = value,
                .definition = definition,
                .label = label,
            };

            if (quantity_registry) |registry|
                try registry.adopt(self);

            return self;
        }

        pub fn deinit(self: *Self) void {
            getAllocator().destroy(self);
        }

        fn hasSameDefinition(self: *const Self, definition: *const NumericDefinition) !bool {
            return self.definition.eql(definition.*);
        }

        pub fn assertSameDefinition(self: *const Self, definition: *const NumericDefinition) !void {
            if (!try self.hasSameDefinition(definition))
                unreachable; // Definitions must match
        }

        pub fn operate(
            comptime operation: ArithmeticOperation,
            lhs: *const Self,
            rhs: *const Self,
            label: ?[]const u8,
        ) !*Self {
            try rhs.assertSameDefinition(lhs.definition);

            const value: *Numeric = switch (operation) {
                .add => try .add(lhs.value, rhs.value),
                .sub => try .sub(lhs.value, rhs.value),
                else => unreachable, // Unsupported operation
            };

            return try init(
                value,
                lhs.definition,
                label,
            );
        }

        pub fn scaleValue(
            comptime operation: ArithmeticOperation,
            lhs: *const Self,
            rhs: *const Numeric,
            label: ?[]const u8,
        ) !Self {
            const value: *Numeric = switch (operation) {
                .mul => try .mul(lhs.value, rhs),
                .div => try .div(lhs.value, rhs),
            };

            return try init(
                value,
                lhs.definition,
                label,
            );
        }

        pub fn combine(
            comptime operation: ArithmeticOperation,
            comptime cross_cancellation: bool,
            lhs: *const Self,
            rhs: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
            existing: ?*NumericDefinition,
            label: ?[]const u8,
        ) !*Self {
            const definition: *NumericDefinition = try .combine(
                operation,
                cross_cancellation,
                lhs.definition,
                rhs.definition,
                constraint,
                name,
                existing,
            );

            const value: *Numeric = switch (operation) {
                .mul => try .mul(lhs.value, rhs.value),
                .div => try .div(lhs.value, rhs.value),
                else => unreachable, // Unsupported operation
            };

            return try init(
                value,
                definition,
                label,
            );
        }

        pub fn add(
            lhs: *const Self,
            rhs: *const Self,
            label: ?[]const u8,
        ) !*Self {
            return operate(.add, lhs, rhs, label);
        }

        pub fn sub(
            lhs: *const Self,
            rhs: *const Self,
            label: ?[]const u8,
        ) !*Self {
            return operate(.sub, lhs, rhs, label);
        }

        pub fn scale(
            lhs: *const Self,
            rhs: *const Numeric,
            label: ?[]const u8,
        ) !*Self {
            return scaleValue(.mul, lhs, rhs, label);
        }

        pub fn unscale(
            lhs: *const Self,
            rhs: *const Numeric,
            label: ?[]const u8,
        ) !*Self {
            return scaleValue(.div, lhs, rhs, label);
        }

        pub fn mul(
            comptime cross_cancellation: bool,
            lhs: *const Self,
            rhs: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
            label: ?[]const u8,
            existing: ?*NumericDefinition,
        ) !*Self {
            return combine(
                .mul,
                cross_cancellation,
                lhs,
                rhs,
                constraint,
                name,
                existing,
                label,
            );
        }

        pub fn div(
            comptime cross_cancellation: bool,
            lhs: *const Self,
            rhs: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
            label: ?[]const u8,
            existing: ?*NumericDefinition,
        ) !*Self {
            return combine(
                .div,
                cross_cancellation,
                lhs,
                rhs,
                constraint,
                name,
                existing,
                label,
            );
        }

        pub fn write(self: *const Self, writer: *std.Io.Writer) !void {
            try self.writeLabel(writer);

            // try self.value.writeFraction(writer);
            try self.value.writeDecimal(writer, config.decimal_precision);

            try writer.writeByte(' ');
            try self.definition.writeUnits(writer);
        }

        fn writeLabel(
            self: *const Self,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            if (self.label) |label|
                try writer.print("{s} = ", .{label});
        }

        fn getAllocator() Allocator {
            return allocator orelse unreachable; // Allocator must be initialized
        }
    };
}
