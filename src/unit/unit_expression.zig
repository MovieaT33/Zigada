// Checked style

const std = @import("std");

const UnitFactor = @import("unit_factor.zig").UnitFactor;

const Allocator = std.mem.Allocator;

pub const UnitExpression = struct {
    const Self = @This();

    pub const FactorSide = enum {
        numerator,
        denominator,

        fn opposite(self: @This()) @This() {
            return switch (self) {
                .numerator => .denominator,
                .denominator => .numerator,
            };
        }
    };

    pub const CancelResult = enum {
        no_match,
        remove_denominator,
        remove_numerator,
        remove_both,
    };

    pub const Operation = enum {
        mul,
        div,
    };

    allocator: Allocator,
    name: ?[]const u8,
    numerator: std.ArrayList(UnitFactor),
    denominator: std.ArrayList(UnitFactor),

    pub fn init(
        allocator: Allocator,
        name: ?[]const u8,
    ) Allocator.Error!*Self {
        const self = try allocator.create(Self);

        self.* = .{
            .allocator = allocator,
            .name = name,
            .numerator = .empty,
            .denominator = .empty,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.numerator.deinit(self.allocator);
        self.denominator.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    fn copyFrom(
        self: *Self,
        source: *const Self,
    ) Allocator.Error!void {
        self.numerator.clearRetainingCapacity();
        self.denominator.clearRetainingCapacity();

        try self.numerator.appendSlice(
            self.allocator,
            source.numerator.items,
        );

        try self.denominator.appendSlice(
            self.allocator,
            source.denominator.items,
        );
    }

    fn clone(
        self: *const Self,
        name: ?[]const u8,
    ) Allocator.Error!*Self {
        var expression: *Self = try .init(self.allocator, name);
        errdefer expression.deinit();

        try expression.copyFrom(self);

        return expression;
    }

    pub fn eql(a: Self, b: Self) bool {
        return factorsEql(a, b, .numerator) and
            factorsEql(a, b, .denominator);
    }

    pub fn addFactor(
        self: *Self,
        factor: UnitFactor,
        side: FactorSide,
    ) Allocator.Error!void {
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

        try factors.append(self.allocator, factor);
    }

    pub fn addFactors(
        self: *Self,
        factors: []const UnitFactor,
        side: FactorSide,
    ) Allocator.Error!void {
        for (factors) |factor|
            try self.addFactor(factor, side);
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
                    .remove_denominator => _ = self.denominator.orderedRemove(denominator_index),
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

    pub fn combine(
        left: *const Self,
        right: *const Self,
        comptime operation: Operation,
        name: ?[]const u8,
        comptime cross_cancellation: bool,
    ) Allocator.Error!*Self {
        var expression = try left.clone(name);

        const right_side: FactorSide = switch (operation) {
            .mul => .numerator,
            .div => .denominator,
        };

        try expression.addFactors(
            right.numerator.items,
            right_side,
        );

        try expression.addFactors(
            right.denominator.items,
            right_side.opposite(),
        );

        if (cross_cancellation)
            expression.crossCancel();

        return expression;
    }

    pub fn toText(self: *const Self) !std.ArrayList(u8) {
        var text: std.ArrayList(u8) = .empty;
        errdefer text.deinit(self.allocator);

        try self.appendNumerator(&text);
        try self.appendDenominator(&text);

        return text;
    }

    pub fn writeName(
        self: *const Self,
        io: *const std.Io,
    ) std.Io.File.WriteFilePositionalError!void {
        var stdout = std.Io.File.stdout();

        if (self.name) |name| {
            try stdout.writePositionalAll(io.*, "[", 0);
            try stdout.writePositionalAll(io.*, name, 0);
            try stdout.writePositionalAll(io.*, "] = ", 0);
        }
    }

    pub fn writeUnits(
        self: *const Self,
        io: *const std.Io,
    ) !void {
        var text = try self.toText();
        defer text.deinit(self.allocator);

        var stdout = std.Io.File.stdout();

        try stdout.writePositionalAll(io.*, text.items, 0);
    }

    pub fn write(
        self: *const Self,
        io: *const std.Io,
    ) !void {
        try self.writeName(io);
        try self.writeUnits(io);

        var stdout = std.Io.File.stdout();

        try stdout.writePositionalAll(io.*, "\n", 0);
    }

    fn factorsEql(a: Self, b: Self, side: FactorSide) bool {
        const a_factors = switch (side) {
            .numerator => a.numerator.items,
            .denominator => a.denominator.items,
        };

        const b_factors = switch (side) {
            .numerator => b.numerator.items,
            .denominator => b.denominator.items,
        };

        if (a_factors.len != b_factors.len)
            return false;

        for (a_factors) |factor| {
            var matched = false;

            for (b_factors) |other| {
                if (!std.mem.eql(u8, factor.unit, other.unit))
                    continue;

                if (factor.power == other.power) {
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
            self.allocator,
            text,
            self.numerator.items,
        );
    }

    fn appendDenominator(
        self: *const Self,
        text: *std.ArrayList(u8),
    ) !void {
        if (self.denominator.items.len == 0)
            return;

        try text.append(self.allocator, '/');

        const parenthesize = self.denominator.items.len > 1;

        if (parenthesize)
            try text.append(self.allocator, '(');

        try UnitFactor.appendFactors(
            self.allocator,
            text,
            self.denominator.items,
        );

        if (parenthesize)
            try text.append(self.allocator, ')');
    }
};
