const std = @import("std");

const config = @import("config.zig");
const UnitFactor = @import("unit_factor.zig").UnitFactor;

const Allocator = std.mem.Allocator;

pub const Dimension = struct {
    const Self = @This();

    const Side = enum(u8) {
        numerator,
        denominator,
    };

    pub const Operation = enum(u8) {
        mul,
        div,
    };

    name: ?[]const u8,
    numerator: std.ArrayList(UnitFactor),
    denominator: std.ArrayList(UnitFactor),
    allocator: *Allocator,

    pub fn init(
        name: ?[]const u8,
        allocator: *Allocator,
    ) Allocator.Error!*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .name = name,
            .numerator = .empty,
            .denominator = .empty,
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.allocator.*;

        self.numerator.deinit(allocator);
        self.denominator.deinit(allocator);

        allocator.destroy(self);
    }

    pub fn add(
        self: *Dimension,
        factor: UnitFactor,
        side: Side,
    ) Allocator.Error!void {
        const list = switch (side) {
            .numerator => &self.numerator,
            .denominator => &self.denominator,
        };

        for (list.items) |*existing| {
            if (std.mem.eql(u8, existing.name, factor.name)) {
                existing.power += factor.power;
                return;
            }
        }

        try list.append(self.allocator.*, factor);
    }

    pub fn clone(
        self: *const Self,
        name: ?[]const u8,
    ) Allocator.Error!*Self {
        const cloned = try Self.init(name, self.allocator);
        errdefer cloned.deinit();

        const allocator = self.allocator.*;

        try cloned.numerator.appendSlice(
            allocator,
            self.numerator.items,
        );

        try cloned.denominator.appendSlice(
            allocator,
            self.denominator.items,
        );

        return cloned;
    }

    fn factorsEql(a: Self, b: Self, side: Side) bool {
        const a_factors = switch (side) {
            .numerator => a.numerator.items,
            .denominator => a.denominator.items,
        };

        const b_factors = switch (side) {
            .numerator => b.numerator.items,
            .denominator => b.denominator.items,
        };

        // Check every factor from `a`.
        for (a_factors) |factor| {
            var found = false;

            // Search for the same factor in `b`.
            for (b_factors) |other| {
                if (std.mem.eql(u8, factor.name, other.name) and
                    factor.power == other.power)
                {
                    // Matching name and power were found.
                    found = true;
                    break;
                }
            }

            if (!found)
                return false;
        }

        return true;
    }

    pub fn eql(a: Self, b: Self) bool {
        const a_numerator_len = a.numerator.items.len;
        const b_numerator_len = b.numerator.items.len;

        const a_denominator_len = a.denominator.items.len;
        const b_denominator_len = b.denominator.items.len;

        if (a_numerator_len != b_numerator_len)
            return false;

        if (a_denominator_len != b_denominator_len)
            return false;

        if (a_numerator_len == 0 and a_denominator_len == 0)
            return true;

        return factorsEql(a, b, .numerator) and
            factorsEql(a, b, .denominator);
    }

    pub fn operate(
        a: *Self,
        b: *Self,
        comptime operation: Operation,
        name: ?[]const u8,
        comptime cross_cancellation: bool,
    ) Allocator.Error!*Self {
        var cloned = try a.clone(name);

        const b_numerator_side: Side = switch (operation) {
            .mul => .numerator,
            .div => .denominator,
        };

        const b_denominator_side: Side = switch (operation) {
            .mul => .denominator,
            .div => .numerator,
        };

        for (b.numerator.items) |factor|
            try cloned.add(factor, b_numerator_side);

        for (b.denominator.items) |factor|
            try cloned.add(factor, b_denominator_side);

        if (cross_cancellation)
            cloned.crossCancel();

        return cloned;
    }

    pub fn crossCancel(self: *Self) void {
        var i: usize = 0;

        while (i < self.numerator.items.len) {
            var j: usize = 0;

            while (j < self.denominator.items.len) {
                const numerator = &self.numerator.items[i];
                const denominator = &self.denominator.items[j];

                if (std.mem.eql(u8, numerator.name, denominator.name)) {
                    if (numerator.power > denominator.power) {
                        numerator.power -= denominator.power;
                        _ = self.denominator.orderedRemove(j);
                    } else if (numerator.power < denominator.power) {
                        denominator.power -= numerator.power;
                        _ = self.numerator.orderedRemove(i);
                        break;
                    } else {
                        _ = self.numerator.orderedRemove(i);
                        _ = self.denominator.orderedRemove(j);
                        break;
                    }
                } else {
                    j += 1;
                }
            }

            if (i < self.numerator.items.len)
                i += 1;
        }
    }

    fn appendFactor(
        self: *const Self,
        bytes: *std.ArrayList(u8),
        factor: UnitFactor,
    ) !void {
        const allocator = self.allocator.*;

        // Append unit name.
        try bytes.appendSlice(allocator, factor.name);

        // Append power if it is not 1.
        if (factor.power != 1) {
            var buffer: [config.print_buffer_size]u8 = undefined;

            const power = try std.fmt.bufPrint(
                &buffer,
                "^{}",
                .{factor.power},
            );

            try bytes.appendSlice(allocator, power);
        }
    }

    fn appendFactors(
        self: *const Self,
        bytes: *std.ArrayList(u8),
        factors: []const UnitFactor,
    ) !void {
        const allocator = self.allocator.*;

        for (factors, 0..) |factor, i| {
            // Separate factors with '*'.
            if (i != 0)
                try bytes.append(allocator, '*');

            // Append current factor.
            try self.appendFactor(
                bytes,
                factor,
            );
        }
    }

    pub fn toBytes(self: *const Self) !std.ArrayList(u8) {
        const allocator = self.allocator.*;

        var bytes: std.ArrayList(u8) = .empty;
        errdefer bytes.deinit(allocator);

        // Append numerator.
        try self.appendFactors(
            &bytes,
            self.numerator.items,
        );

        // Append denominator.
        const denominator_len = self.denominator.items.len;
        if (denominator_len > 0) {
            try bytes.append(allocator, '/');

            // Use parentheses for multiple denominator factors.
            const use_parentheses = denominator_len > 1;
            if (use_parentheses)
                try bytes.append(allocator, '(');

            try self.appendFactors(
                &bytes,
                self.denominator.items,
            );

            if (use_parentheses)
                try bytes.append(allocator, ')');
        }

        return bytes;
    }

    pub fn showUnits(self: *const Self, io: *const std.Io) !void {
        const allocator = self.allocator.*;

        var bytes = try self.toBytes();
        defer bytes.deinit(allocator);

        var stdout = std.Io.File.stdout();

        try stdout.writePositionalAll(
            io.*,
            bytes.items,
            0,
        );
    }

    pub fn showName(self: *const Self, io: *const std.Io) std.Io.File.WriteFilePositionalError!void {
        var stdout = std.Io.File.stdout();

        if (self.name) |name| {
            try stdout.writePositionalAll(io.*, "[", 0);
            try stdout.writePositionalAll(io.*, name, 0);
            try stdout.writePositionalAll(io.*, "] = ", 0);
        }
    }

    pub fn show(self: *const Self, io: *const std.Io) !void {
        try self.showName(io);

        try self.showUnits(io);

        var stdout = std.Io.File.stdout();
        try stdout.writePositionalAll(io.*, "\n", 0);
    }
};
