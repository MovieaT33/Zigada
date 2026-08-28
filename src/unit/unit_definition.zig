const std = @import("std");

const ArithmeticOperation = @import("../arithmetic_operation.zig").ArithmeticOperation;
const UnitRegistry = @import("unit_registry.zig").UnitRegistry;

const Allocator = std.mem.Allocator;

pub fn UnitDefinition(comptime Numeric: type) type {
    return struct {
        const Self = @This();

        const UnitFactor = struct {
            unit: []const u8,
            power: u8,

            pub fn appendPower(
                self: *const @This(),
                writer: *std.Io.Writer,
            ) std.Io.Writer.Error!void {
                try writer.print("^{}", .{self.power});
            }

            pub fn appendText(
                self: *const @This(),
                writer: *std.Io.Writer,
            ) std.Io.Writer.Error!void {
                try writer.print("{s}", .{self.unit});

                if (self.power != 1)
                    try self.appendPower(writer);
            }

            pub fn appendFactors(
                writer: *std.Io.Writer,
                factors: []const @This(),
            ) !void {
                for (factors, 0..) |factor, index| {
                    if (index != 0)
                        try writer.writeByte('*');

                    try factor.appendText(writer);
                }
            }
        };

        pub const Constraint = struct {
            min: ?*Numeric = null,
            max: ?*Numeric = null,

            pub fn init(min: ?*Numeric, max: ?*Numeric) @This() {
                return .{
                    .min = min,
                    .max = max,
                };
            }

            pub fn clone(self: *const @This()) !@This() {
                return .{
                    .min = if (self.min) |min|
                        try min.clone()
                    else
                        null,

                    .max = if (self.max) |max|
                        try max.clone()
                    else
                        null,
                };
            }

            pub fn validate(self: *const @This(), value: *const Numeric) !void {
                if (self.min) |min|
                    if (try value.lessThan(min))
                        return error.BelowMinimum;

                if (self.max) |max|
                    if (try value.greaterThan(max))
                        return error.AboveMaximum;
            }
        };

        const FactorSide = enum {
            numerator,
            denominator,

            fn opposite(self: @This()) @This() {
                return switch (self) {
                    .numerator => .denominator,
                    .denominator => .numerator,
                };
            }
        };

        const CancelResult = enum {
            no_match,
            remove_denominator,
            remove_numerator,
            remove_both,
        };

        pub var allocator: ?Allocator = null;
        pub var unit_registry: ?*UnitRegistry(Self) = null;

        numerator: std.ArrayList(UnitFactor),
        denominator: std.ArrayList(UnitFactor),
        constraint: Constraint,
        name: ?[]const u8,

        pub fn init(
            numerator_factors: []const UnitFactor,
            denominator_factors: []const UnitFactor,
            constraint: Constraint,
            name: ?[]const u8,
        ) Allocator.Error!*Self {
            const _allocator = getAllocator();

            const self = try _allocator.create(Self);
            errdefer _allocator.destroy(self);

            self.* = .{
                .numerator = .empty,
                .denominator = .empty,
                .constraint = constraint,
                .name = name,
            };

            try self.addFactors(.numerator, numerator_factors);
            try self.addFactors(.denominator, denominator_factors);

            if (unit_registry) |registry|
                try registry.adopt(self);

            return self;
        }

        pub fn deinit(self: *Self) void {
            const _allocator = getAllocator();

            self.numerator.deinit(_allocator);
            self.denominator.deinit(_allocator);

            _allocator.destroy(self);
        }

        pub fn unadopt(self: *Self) void {
            if (unit_registry) |registry|
                registry.unadopt(self);
        }

        pub fn clone(
            self: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) Allocator.Error!*Self {
            return try init(
                self.numerator.items,
                self.denominator.items,
                constraint,
                name,
            );
        }

        pub fn eql(lhs: Self, rhs: Self) !bool {
            return factorsEql(.numerator, lhs, rhs) and
                factorsEql(.denominator, lhs, rhs) and
                try constraintsEql(lhs.constraint, rhs.constraint);
        }

        fn factorsEql(
            comptime side: FactorSide,
            lhs: Self,
            rhs: Self,
        ) bool {
            const lhs_factors = switch (side) {
                .numerator => lhs.numerator.items,
                .denominator => lhs.denominator.items,
            };

            const rhs_factors = switch (side) {
                .numerator => rhs.numerator.items,
                .denominator => rhs.denominator.items,
            };

            if (lhs_factors.len != rhs_factors.len)
                return false;

            for (lhs_factors) |lhs_factor| {
                var matched = false;

                for (rhs_factors) |rhs_factor| {
                    if (std.mem.eql(u8, lhs_factor.unit, rhs_factor.unit)) {
                        if (lhs_factor.power != rhs_factor.power)
                            return false;

                        matched = true;
                        break;
                    }
                }

                if (!matched)
                    return false;
            }

            return true;
        }

        fn constraintsEql(lhs: Constraint, rhs: Constraint) !bool {
            return try optionalNumericEql(lhs.min, rhs.min) and
                try optionalNumericEql(lhs.max, rhs.max);
        }

        fn optionalNumericEql(lhs: ?*const Numeric, rhs: ?*const Numeric) !bool {
            if (lhs) |lhs_value| {
                if (rhs) |rhs_value|
                    return try lhs_value.eql(rhs_value);

                return false;
            }

            return rhs == null;
        }

        fn addFactor(
            self: *Self,
            side: FactorSide,
            factor: UnitFactor,
        ) Allocator.Error!void {
            const _allocator = getAllocator();

            const factors = switch (side) {
                .numerator => &self.numerator,
                .denominator => &self.denominator,
            };

            for (factors.items) |*existing| {
                if (std.mem.eql(u8, existing.unit, factor.unit)) {
                    existing.power += factor.power;
                    return;
                }
            }

            try factors.append(_allocator, factor);
        }

        fn addFactors(
            self: *Self,
            side: FactorSide,
            factors: []const UnitFactor,
        ) Allocator.Error!void {
            for (factors) |factor|
                try self.addFactor(side, factor);
        }

        pub fn crossCancel(self: *Self) void {
            var numerator_index: usize = 0;

            while (numerator_index < self.numerator.items.len) {
                var denominator_index: usize = 0;
                var removed_numerator = false;

                while (denominator_index < self.denominator.items.len) {
                    const cancel_result = cancelFactors(
                        &self.numerator.items[numerator_index],
                        &self.denominator.items[denominator_index],
                    );

                    switch (cancel_result) {
                        .no_match => denominator_index += 1,

                        .remove_denominator => {
                            _ = self.denominator.orderedRemove(denominator_index);
                        },

                        .remove_numerator => {
                            _ = self.numerator.orderedRemove(numerator_index);
                            removed_numerator = true;
                            break;
                        },

                        .remove_both => {
                            _ = self.numerator.orderedRemove(numerator_index);
                            _ = self.denominator.orderedRemove(denominator_index);
                            removed_numerator = true;
                            break;
                        },
                    }
                }

                if (!removed_numerator)
                    numerator_index += 1;
            }
        }

        fn cancelFactors(
            numerator: *UnitFactor,
            denominator: *UnitFactor,
        ) CancelResult {
            if (!std.mem.eql(u8, numerator.unit, denominator.unit))
                return .no_match;

            if (numerator.power > denominator.power) {
                numerator.power -= denominator.power;
                return .remove_denominator;
            }

            if (numerator.power < denominator.power) {
                denominator.power -= numerator.power;
                return .remove_numerator;
            }

            return .remove_both;
        }

        pub fn combine(
            comptime operation: ArithmeticOperation,
            comptime cross_cancellation: bool,
            lhs: *const Self,
            rhs: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
            // WARNING: When using `existing`, the returned definition is the same object
            // as `existing`. Do not modify either definition afterward, as they share
            // the same object and modifying one will modify the other.
            existing: ?*Self,
        ) Allocator.Error!*Self {
            var definition = try lhs.clone(
                constraint,
                name,
            );

            const rhs_side: FactorSide = switch (operation) {
                .mul => .numerator,
                .div => .denominator,
                else => unreachable, // Unsupported operation
            };

            try definition.addFactors(
                rhs_side,
                rhs.numerator.items,
            );

            try definition.addFactors(
                rhs_side.opposite(),
                rhs.denominator.items,
            );

            if (cross_cancellation)
                definition.crossCancel();

            if (existing) |existing_definition| {
                if (try existing_definition.eql(definition.*)) {
                    definition.unadopt();
                    definition.deinit();
                    return existing_definition;
                } else {
                    unreachable; // Definitions must match
                }
            }

            return definition;
        }

        pub fn mul(
            comptime cross_cancellation: bool,
            lhs: *const Self,
            rhs: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
            existing: ?*Self,
        ) Allocator.Error!*Self {
            return combine(
                .mul,
                cross_cancellation,
                lhs,
                rhs,
                constraint,
                name,
                existing,
            );
        }

        pub fn div(
            comptime cross_cancellation: bool,
            lhs: *const Self,
            rhs: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
            existing: ?*Self,
        ) Allocator.Error!*Self {
            return combine(
                .div,
                cross_cancellation,
                lhs,
                rhs,
                constraint,
                name,
                existing,
            );
        }

        pub fn write(
            self: *const Self,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            if (self.name != null) {
                try self.writeName(writer);
                try writer.writeAll(" = ");
            }

            try self.writeUnits(writer);
        }

        pub fn writeName(
            self: *const Self,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            if (self.name) |name|
                try writer.print("[{s}]", .{name});
        }

        pub fn writeUnits(
            self: *const Self,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try self.appendNumerator(writer);
            try self.appendDenominator(writer);
        }

        fn appendNumerator(
            self: *const Self,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try UnitFactor.appendFactors(
                writer,
                self.numerator.items,
            );
        }

        fn appendDenominator(
            self: *const Self,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            if (self.denominator.items.len == 0)
                return;

            try writer.writeByte('/');

            const parenthesize = self.denominator.items.len > 1;

            if (parenthesize)
                try writer.writeByte('(');

            try UnitFactor.appendFactors(
                writer,
                self.denominator.items,
            );

            if (parenthesize)
                try writer.writeByte(')');
        }

        fn getAllocator() Allocator {
            return allocator orelse unreachable; // Allocator must be initialized
        }
    };
}
