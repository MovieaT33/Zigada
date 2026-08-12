const std = @import("std");

const Operation = @import("../operation.zig").Operation;
const UnitRegistry = @import("unit_registry.zig").UnitRegistry;

const Allocator = std.mem.Allocator;

pub fn UnitDefinition(comptime N: type) type {
    return struct {
        const Self = @This();

        const UnitFactor = struct {
            unit: []const u8,
            power: u8,

            pub fn appendPower(
                self: *const @This(),
                text: *std.ArrayList(u8),
            ) !void {
                const alloc = getAllocator();

                var print_buffer: [4]u8 = undefined; // "^255"

                const power_text = try std.fmt.bufPrint(
                    &print_buffer,
                    "^{}",
                    .{self.power},
                );

                try text.appendSlice(alloc, power_text);
            }

            pub fn appendText(
                self: *const @This(),
                text: *std.ArrayList(u8),
            ) !void {
                const alloc = getAllocator();

                try text.appendSlice(alloc, self.unit);

                if (self.power != 1)
                    try self.appendPower(text);
            }

            pub fn appendFactors(
                text: *std.ArrayList(u8),
                factors: []const @This(),
            ) !void {
                const alloc = getAllocator();

                for (factors, 0..) |factor, index| {
                    if (index != 0)
                        try text.append(alloc, '*');

                    try factor.appendText(text);
                }
            }
        };

        pub const Constraint = struct {
            min: ?*N = null,
            max: ?*N = null,

            pub fn init(min: ?*N, max: ?*N) @This() {
                return .{
                    .min = min,
                    .max = max,
                };
            }

            pub fn validate(self: *const @This(), value: *const N) !void {
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
        pub var unit_registry: ?*UnitRegistry(N) = null;

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
            const alloc = getAllocator();

            const self = try alloc.create(Self);
            errdefer alloc.destroy(self);

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
            const alloc = getAllocator();

            self.numerator.deinit(alloc);
            self.denominator.deinit(alloc);

            alloc.destroy(self);
        }

        pub fn copyFrom(
            self: *Self,
            source: *const Self,
        ) Allocator.Error!void {
            const alloc = getAllocator();

            self.numerator.clearRetainingCapacity();
            self.denominator.clearRetainingCapacity();

            try self.numerator.appendSlice(
                alloc,
                source.numerator.items,
            );

            try self.denominator.appendSlice(
                alloc,
                source.denominator.items,
            );
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

        pub fn eql(left: Self, right: Self) bool {
            return factorsEql(.numerator, left, right) and
                factorsEql(.denominator, left, right);
        }

        fn addFactor(
            self: *Self,
            side: FactorSide,
            factor: UnitFactor,
        ) Allocator.Error!void {
            const alloc = getAllocator();

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

            try factors.append(alloc, factor);
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
                    switch (cancelFactors(
                        &self.numerator.items[numerator_index],
                        &self.denominator.items[denominator_index],
                    )) {
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

        pub fn mul(
            comptime cross_cancellation: bool,
            left: *const Self,
            right: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) Allocator.Error!*Self {
            return combine(
                .mul,
                cross_cancellation,
                left,
                right,
                constraint,
                name,
            );
        }

        pub fn div(
            comptime cross_cancellation: bool,
            left: *const Self,
            right: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) Allocator.Error!*Self {
            return combine(
                .div,
                cross_cancellation,
                left,
                right,
                constraint,
                name,
            );
        }

        pub fn combine(
            comptime operation: Operation,
            comptime cross_cancellation: bool,
            left: *const Self,
            right: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) Allocator.Error!*Self {
            var definition = try left.clone(constraint, name);

            const right_side: FactorSide = switch (operation) {
                .mul => .numerator,
                .div => .denominator,
                else => unreachable,
            };

            try definition.addFactors(
                right_side,
                right.numerator.items,
            );

            try definition.addFactors(
                right_side.opposite(),
                right.denominator.items,
            );

            if (cross_cancellation)
                definition.crossCancel();

            return definition;
        }

        pub fn toText(self: *const Self) !std.ArrayList(u8) {
            const alloc = getAllocator();

            var text: std.ArrayList(u8) = .empty;
            errdefer text.deinit(alloc);

            try self.appendNumerator(&text);
            try self.appendDenominator(&text);

            return text;
        }

        pub fn writeName(
            self: *const Self,
            io: std.Io,
        ) std.Io.File.WriteFilePositionalError!void {
            var stdout: std.Io.File = .stdout();

            if (self.name) |name| {
                try stdout.writePositionalAll(io, "[", 0);
                try stdout.writePositionalAll(io, name, 0);
                try stdout.writePositionalAll(io, "] = ", 0);
            }
        }

        pub fn writeUnits(
            self: *const Self,
            io: std.Io,
        ) !void {
            const alloc = getAllocator();

            var text = try self.toText();
            defer text.deinit(alloc);

            var stdout: std.Io.File = .stdout();
            try stdout.writePositionalAll(io, text.items, 0);
        }

        pub fn write(
            self: *const Self,
            io: std.Io,
        ) !void {
            try self.writeName(io);
            try self.writeUnits(io);

            var stdout: std.Io.File = .stdout();
            try stdout.writePositionalAll(io, "\n", 0);
        }

        fn getAllocator() Allocator {
            return allocator orelse unreachable;
        }

        fn factorsEql(
            comptime side: FactorSide,
            left: Self,
            right: Self,
        ) bool {
            const left_factors = switch (side) {
                .numerator => left.numerator.items,
                .denominator => left.denominator.items,
            };

            const right_factors = switch (side) {
                .numerator => right.numerator.items,
                .denominator => right.denominator.items,
            };

            if (left_factors.len != right_factors.len)
                return false;

            for (left_factors) |left_factor| {
                var matched = false;

                for (right_factors) |right_factor| {
                    if (std.mem.eql(u8, left_factor.unit, right_factor.unit)) {
                        if (left_factor.power != right_factor.power)
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

        fn appendNumerator(
            self: *const Self,
            text: *std.ArrayList(u8),
        ) !void {
            try UnitFactor.appendFactors(
                text,
                self.numerator.items,
            );
        }

        fn appendDenominator(
            self: *const Self,
            text: *std.ArrayList(u8),
        ) !void {
            const alloc = getAllocator();

            if (self.denominator.items.len == 0)
                return;

            try text.append(alloc, '/');

            const parenthesize = self.denominator.items.len > 1;

            if (parenthesize)
                try text.append(alloc, '(');

            try UnitFactor.appendFactors(
                text,
                self.denominator.items,
            );

            if (parenthesize)
                try text.append(alloc, ')');
        }
    };
}
