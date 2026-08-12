const std = @import("std");

const Operation = @import("../operation.zig").Operation;
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

        pub fn init(
            value: *const Numeric,
            definition: *const NumericDefinition,
        ) !*Self {
            const alloc = getAllocator();

            try definition.constraint.validate(value);

            const self = try alloc.create(Self);
            errdefer alloc.destroy(self);

            self.* = .{
                .value = value,
                .definition = definition,
            };

            if (quantity_registry) |registry|
                try registry.adopt(self);

            return self;
        }

        pub fn deinit(self: *Self) void {
            getAllocator().destroy(self);
        }

        pub fn operate(
            comptime operation: Operation,
            lhs: *const Self,
            rhs: *const Self,
        ) !*Self {
            if (!lhs.definition.eql(rhs.definition.*))
                unreachable;

            const value: *Numeric = switch (operation) {
                .add => try .add(lhs.value, rhs.value),
                .sub => try .sub(lhs.value, rhs.value),
                else => unreachable,
            };

            return try init(
                value,
                lhs.definition,
            );
        }

        pub fn scaleValue(
            comptime operation: Operation,
            lhs: *const Self,
            rhs: *const Numeric,
        ) !Self {
            const value: *Numeric = switch (operation) {
                .mul => try .mul(lhs.value, rhs),
                .div => try .div(lhs.value, rhs),
            };

            return try init(
                value,
                lhs.definition,
            );
        }

        pub fn combine(
            comptime operation: Operation,
            comptime cross_cancellation: bool,
            lhs: *const Self,
            rhs: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) !*Self {
            const definition: *NumericDefinition = try .combine(
                operation,
                cross_cancellation,
                lhs.definition,
                rhs.definition,
                constraint,
                name,
            );

            const value: *Numeric = switch (operation) {
                .mul => try .mul(lhs.value, rhs.value),
                .div => try .div(lhs.value, rhs.value),
                else => unreachable,
            };

            return try init(
                value,
                definition,
            );
        }

        pub fn add(lhs: *const Self, rhs: *const Self) !*Self {
            return operate(.add, lhs, rhs);
        }

        pub fn sub(lhs: *const Self, rhs: *const Self) !*Self {
            return operate(.sub, lhs, rhs);
        }

        pub fn scale(lhs: *const Self, rhs: *const Numeric) !*Self {
            return scaleValue(.mul, lhs, rhs);
        }

        pub fn unscale(lhs: *const Self, rhs: *const Numeric) !*Self {
            return scaleValue(.div, lhs, rhs);
        }

        pub fn mul(
            comptime cross_cancellation: bool,
            lhs: *const Self,
            rhs: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) !*Self {
            return combine(
                .mul,
                cross_cancellation,
                lhs,
                rhs,
                constraint,
                name,
            );
        }

        pub fn div(
            comptime cross_cancellation: bool,
            lhs: *const Self,
            rhs: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) !*Self {
            return combine(
                .div,
                cross_cancellation,
                lhs,
                rhs,
                constraint,
                name,
            );
        }

        pub fn write(
            self: *const Self,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try self.value.write(writer);
            try writer.writeByte(' ');
            try self.definition.writeUnits(writer);
        }

        fn getAllocator() Allocator {
            return allocator orelse unreachable;
        }
    };
}
