const std = @import("std");

const UnitFactor = @import("unit_factor.zig").UnitFactor;

const Allocator = std.mem.Allocator;

pub const UnitExpression = struct {
    const Self = @This();

    pub const FactorSide = enum(u8) {
        numerator,
        denominator,

        fn opposite(self: @This()) @This() {
            return switch (self) {
                .numerator => .denominator,
                .denominator => .numerator,
            };
        }
    };

    pub const CancelResult = enum(u8) {
        no_match,
        remove_denominator,
        remove_numerator,
        remove_both,
    };

    pub const Operation = enum(u8) {
        mul,
        div,
    };

    name: ?[]const u8,
    numerator: std.ArrayList(UnitFactor),
    denominator: std.ArrayList(UnitFactor),
    allocator: Allocator,

    pub fn init(
        name: ?[]const u8,
        allocator: Allocator,
    ) Allocator.Error!*Self {
        const self = try allocator.create(Self);

        self.* = .{
            .name = name,
            .numerator = .empty,
            .denominator = .empty,
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.allocator;

        self.numerator.deinit(allocator);
        self.denominator.deinit(allocator);

        allocator.destroy(self);
    }

    fn copyFrom(
        self: *Self,
        source: *const Self,
    ) Allocator.Error!void {
        const allocator = self.allocator;

        self.numerator.clearRetainingCapacity();
        self.denominator.clearRetainingCapacity();

        try self.numerator.appendSlice(
            allocator,
            source.numerator.items,
        );

        try self.denominator.appendSlice(
            allocator,
            source.denominator.items,
        );
    }

    fn copyWithName(
        self: *const Self,
        name: ?[]const u8,
    ) Allocator.Error!*Self {
        var result = try Self.init(name, self.allocator);
        errdefer result.deinit();

        try result.copyFrom(self);

        return result;
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
        const list = switch (side) {
            .numerator => &self.numerator,
            .denominator => &self.denominator,
        };

        for (list.items) |*existing| {
            if (std.mem.eql(u8, existing.unit, factor.unit)) {
                existing.power += factor.power;
                return;
            }
        }

        try list.append(self.allocator, factor);
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
        for (self.numerator.items, 0..) |_, numerator_index| {
            var denominator_index: usize = 0;

            while (denominator_index < self.denominator.items.len) {
                const result = cancelFactors(
                    &self.numerator.items[numerator_index],
                    &self.denominator.items[denominator_index],
                );

                switch (result) {
                    .no_match => denominator_index += 1,

                    .remove_denominator => {
                        _ = self.denominator.orderedRemove(denominator_index);
                    },

                    .remove_numerator => {
                        _ = self.numerator.orderedRemove(numerator_index);
                        break;
                    },

                    .remove_both => {
                        _ = self.numerator.orderedRemove(numerator_index);
                        _ = self.denominator.orderedRemove(denominator_index);
                        break;
                    },
                }
            }
        }
    }

    pub fn combine(
        a: *const Self,
        b: *const Self,
        comptime op: Operation,
        name: ?[]const u8,
        comptime cross_cancellation: bool,
    ) Allocator.Error!*Self {
        var result = try a.copyWithName(name);

        const b_numerator_side: FactorSide = switch (op) {
            .mul => .numerator,
            .div => .denominator,
        };

        try result.addFactors(
            b.numerator.items,
            b_numerator_side,
        );

        try result.addFactors(
            b.denominator.items,
            b_numerator_side.opposite(),
        );

        if (cross_cancellation)
            result.crossCancel();

        return result;
    }

    pub fn toText(self: *const Self) !std.ArrayList(u8) {
        var text: std.ArrayList(u8) = .empty;
        errdefer text.deinit(self.allocator);

        try self.appendNumerator(&text);
        try self.appendDenominator(&text);

        return text;
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
            text,
            self.numerator.items,
            self.allocator,
        );
    }

    fn appendDenominator(
        self: *const Self,
        text: *std.ArrayList(u8),
    ) !void {
        if (self.denominator.items.len == 0)
            return;

        try text.append(self.allocator, '/');

        const use_parentheses = self.denominator.items.len > 1;

        if (use_parentheses)
            try text.append(self.allocator, '(');

        try UnitFactor.appendFactors(
            text,
            self.denominator.items,
            self.allocator,
        );

        if (use_parentheses)
            try text.append(self.allocator, ')');
    }
};
