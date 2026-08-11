// Created by ChatGPT

const std = @import("std");

const Allocator = std.mem.Allocator;

pub const BigInt = struct {
    const Limb = u64;
    const Wide = u128;

    limbs: std.ArrayList(Limb),
    negative: bool,
    allocator: Allocator,

    pub fn init(allocator: Allocator) BigInt {
        return .{
            .limbs = .empty,
            .negative = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BigInt) void {
        self.limbs.deinit(self.allocator);
    }

    pub fn clone(
        self: *const BigInt,
        allocator: Allocator,
    ) !BigInt {
        var result = BigInt.init(allocator);
        errdefer result.deinit();

        result.negative = self.negative;

        try result.limbs.appendSlice(
            allocator,
            self.limbs.items,
        );

        return result;
    }

    pub fn isZero(self: *const BigInt) bool {
        return self.limbs.items.len == 0;
    }

    pub fn isOne(self: *const BigInt) bool {
        return !self.negative and
            self.limbs.items.len == 1 and
            self.limbs.items[0] == 1;
    }

    pub fn normalize(self: *BigInt) void {
        while (self.limbs.items.len > 0 and
            self.limbs.items[self.limbs.items.len - 1] == 0)
        {
            _ = self.limbs.pop();
        }

        if (self.isZero())
            self.negative = false;
    }

    pub fn setUnsigned(
        self: *BigInt,
        value: Limb,
    ) !void {
        self.limbs.clearRetainingCapacity();
        self.negative = false;

        if (value == 0)
            return;

        try self.limbs.append(
            self.allocator,
            value,
        );
    }

    pub fn setSigned(
        self: *BigInt,
        value: i64,
    ) !void {
        const magnitude: u64 = if (value < 0)
            @as(u64, @intCast(-(value + 1))) + 1
        else
            @intCast(value);

        self.negative = value < 0;

        try self.setUnsigned(magnitude);
        self.negative = value < 0 and !self.isZero();
    }

    pub fn negate(self: *BigInt) void {
        if (!self.isZero())
            self.negative = !self.negative;
    }

    fn cmpAbs(
        a: *const BigInt,
        b: *const BigInt,
    ) std.math.Order {
        if (a.limbs.items.len < b.limbs.items.len)
            return .lt;

        if (a.limbs.items.len > b.limbs.items.len)
            return .gt;

        var i = a.limbs.items.len;

        while (i > 0) {
            i -= 1;

            if (a.limbs.items[i] < b.limbs.items[i])
                return .lt;

            if (a.limbs.items[i] > b.limbs.items[i])
                return .gt;
        }

        return .eq;
    }

    fn addAbs(
        a: *const BigInt,
        b: *const BigInt,
        allocator: Allocator,
    ) !BigInt {
        var result = BigInt.init(allocator);
        errdefer result.deinit();

        const max_len = @max(
            a.limbs.items.len,
            b.limbs.items.len,
        );

        try result.limbs.ensureTotalCapacity(
            allocator,
            max_len + 1,
        );

        var carry: Wide = 0;

        for (0..max_len) |i| {
            const av: Wide = if (i < a.limbs.items.len)
                a.limbs.items[i]
            else
                0;

            const bv: Wide = if (i < b.limbs.items.len)
                b.limbs.items[i]
            else
                0;

            const sum = av + bv + carry;

            try result.limbs.append(
                allocator,
                @truncate(sum),
            );

            carry = sum >> 64;
        }

        if (carry != 0)
            try result.limbs.append(
                allocator,
                @truncate(carry),
            );

        return result;
    }

    fn subAbs(
        a: *const BigInt,
        b: *const BigInt,
        allocator: Allocator,
    ) !BigInt {
        var result = BigInt.init(allocator);
        errdefer result.deinit();

        try result.limbs.ensureTotalCapacity(
            allocator,
            a.limbs.items.len,
        );

        var borrow: Wide = 0;

        for (0..a.limbs.items.len) |i| {
            const av: Wide = a.limbs.items[i];

            const bv: Wide = if (i < b.limbs.items.len)
                b.limbs.items[i]
            else
                0;

            const subtrahend = bv + borrow;

            if (av >= subtrahend) {
                try result.limbs.append(
                    allocator,
                    @truncate(av - subtrahend),
                );
                borrow = 0;
            } else {
                const value =
                    (@as(Wide, 1) << 64) + av - subtrahend;

                try result.limbs.append(
                    allocator,
                    @truncate(value),
                );
                borrow = 1;
            }
        }

        result.normalize();
        return result;
    }

    pub fn add(
        a: *const BigInt,
        b: *const BigInt,
        allocator: Allocator,
    ) !BigInt {
        if (a.isZero())
            return b.clone(allocator);

        if (b.isZero())
            return a.clone(allocator);

        if (a.negative == b.negative) {
            var result = try addAbs(a, b, allocator);
            result.negative = a.negative;
            return result;
        }

        return switch (cmpAbs(a, b)) {
            .eq => BigInt.init(allocator),
            .gt => blk: {
                var result = try subAbs(a, b, allocator);
                result.negative = a.negative;
                break :blk result;
            },
            .lt => blk: {
                var result = try subAbs(b, a, allocator);
                result.negative = b.negative;
                break :blk result;
            },
        };
    }

    pub fn mul(
        a: *const BigInt,
        b: *const BigInt,
        allocator: Allocator,
    ) !BigInt {
        var result = BigInt.init(allocator);
        errdefer result.deinit();

        if (a.isZero() or b.isZero())
            return result;

        const len =
            a.limbs.items.len +
            b.limbs.items.len;

        try result.limbs.resize(allocator, len);
        @memset(result.limbs.items, 0);

        for (a.limbs.items, 0..) |av, i| {
            var carry: Wide = 0;

            for (b.limbs.items, 0..) |bv, j| {
                const index = i + j;
                const current: Wide =
                    result.limbs.items[index];

                const product =
                    @as(Wide, av) * @as(Wide, bv) +
                    current +
                    carry;

                result.limbs.items[index] = @truncate(product);
                carry = product >> 64;
            }

            var index = i + b.limbs.items.len;

            while (carry != 0) {
                const sum =
                    @as(Wide, result.limbs.items[index]) +
                    carry;

                result.limbs.items[index] = @truncate(sum);
                carry = sum >> 64;
                index += 1;
            }
        }

        result.negative = a.negative != b.negative;
        result.normalize();

        return result;
    }

    pub fn mod(
        a: *const BigInt,
        b: *const BigInt,
        allocator: Allocator,
    ) !BigInt {
        if (b.isZero())
            return error.DivisionByZero;

        var divisor = try b.clone(allocator);
        defer divisor.deinit();

        divisor.negative = false;

        var dividend = try a.clone(allocator);
        defer dividend.deinit();

        dividend.negative = false;

        var result = BigInt.init(allocator);
        errdefer result.deinit();

        if (dividend.isZero())
            return result;

        if (cmpAbs(&dividend, &divisor) == .lt)
            return dividend;

        try result.limbs.ensureTotalCapacity(
            allocator,
            divisor.limbs.items.len,
        );

        var limb_index = dividend.limbs.items.len;

        while (limb_index > 0) {
            limb_index -= 1;

            const limb = dividend.limbs.items[limb_index];

            var bit_index: u7 = 64;

            while (bit_index > 0) {
                bit_index -= 1;

                try shiftLeftOne(&result, allocator);

                if (((limb >> @as(u6, @intCast(bit_index))) & 1) != 0) {
                    try addOne(&result, allocator);
                }

                if (cmpAbs(&result, &divisor) != .lt) {
                    subAbsInPlace(&result, &divisor);
                }
            }
        }

        return result;
    }

    fn shiftLeftOne(
        self: *BigInt,
        allocator: Allocator,
    ) !void {
        if (self.isZero())
            return;

        var carry: Limb = 0;

        for (self.limbs.items) |*limb| {
            const old = limb.*;

            limb.* = (old << 1) | carry;
            carry = old >> 63;
        }

        if (carry != 0)
            try self.limbs.append(allocator, carry);
    }

    fn addOne(
        self: *BigInt,
        allocator: Allocator,
    ) !void {
        if (self.isZero()) {
            try self.limbs.append(allocator, 1);
            return;
        }

        for (self.limbs.items) |*limb| {
            const old = limb.*;

            limb.* +%= 1;

            if (limb.* != 0)
                return;

            _ = old;
        }

        try self.limbs.append(allocator, 1);
    }

    fn subAbsInPlace(
        self: *BigInt,
        other: *const BigInt,
    ) void {
        var borrow: Limb = 0;

        for (self.limbs.items, 0..) |*limb, i| {
            const other_limb: Limb =
                if (i < other.limbs.items.len)
                    other.limbs.items[i]
                else
                    0;

            const subtrahend = @as(Wide, other_limb) + borrow;

            if (@as(Wide, limb.*) >= subtrahend) {
                limb.* = @truncate(
                    @as(Wide, limb.*) - subtrahend,
                );
                borrow = 0;
            } else {
                limb.* = @truncate(
                    (@as(Wide, 1) << 64) +
                        @as(Wide, limb.*) -
                        subtrahend,
                );
                borrow = 1;
            }
        }

        self.normalize();
    }

    pub fn div(
        a: *const BigInt,
        b: *const BigInt,
        allocator: Allocator,
    ) !struct {
        quotient: BigInt,
        remainder: BigInt,
    } {
        if (b.isZero())
            return error.DivisionByZero;

        var quotient = BigInt.init(allocator);
        errdefer quotient.deinit();

        var remainder = BigInt.init(allocator);
        errdefer remainder.deinit();

        if (a.isZero()) {
            return .{
                .quotient = quotient,
                .remainder = remainder,
            };
        }

        var dividend = try a.clone(allocator);
        defer dividend.deinit();
        dividend.negative = false;

        var divisor = try b.clone(allocator);
        defer divisor.deinit();
        divisor.negative = false;

        if (cmpAbs(&dividend, &divisor) == .lt) {
            remainder = try dividend.clone(allocator);

            return .{
                .quotient = quotient,
                .remainder = remainder,
            };
        }

        const bit_count =
            (dividend.limbs.items.len - 1) * 64 +
            (64 - @clz(
                dividend.limbs.items[
                    dividend.limbs.items.len - 1
                ],
            ));

        try quotient.limbs.resize(
            allocator,
            (bit_count + 63) / 64,
        );
        @memset(quotient.limbs.items, 0);

        var bit_index = bit_count;

        while (bit_index > 0) {
            bit_index -= 1;

            try shiftLeftOne(
                &remainder,
                allocator,
            );

            const limb_index = bit_index / 64;
            const bit_in_limb: u6 =
                @intCast(bit_index % 64);

            const bit =
                (dividend.limbs.items[limb_index] >>
                    bit_in_limb) & 1;

            if (bit != 0) {
                try addOne(
                    &remainder,
                    allocator,
                );
            }

            if (cmpAbs(&remainder, &divisor) != .lt) {
                subAbsInPlace(
                    &remainder,
                    &divisor,
                );

                quotient.limbs.items[limb_index] |=
                    @as(Limb, 1) << bit_in_limb;
            }
        }

        quotient.normalize();
        remainder.normalize();

        quotient.negative =
            a.negative != b.negative and
            !quotient.isZero();

        remainder.negative =
            a.negative and
            !remainder.isZero();

        return .{
            .quotient = quotient,
            .remainder = remainder,
        };
    }

    pub fn divExact(
        a: *const BigInt,
        b: *const BigInt,
        allocator: Allocator,
    ) !BigInt {
        var result = try div(
            a,
            b,
            allocator,
        );

        if (!result.remainder.isZero()) {
            result.remainder.deinit();
            result.quotient.deinit();

            return error.NotDivisible;
        }

        result.remainder.deinit();

        return result.quotient;
    }

    pub fn gcd(
        a: *const BigInt,
        b: *const BigInt,
        allocator: Allocator,
    ) !BigInt {
        var x = try a.clone(allocator);
        errdefer x.deinit();

        var y = try b.clone(allocator);
        errdefer y.deinit();

        x.negative = false;
        y.negative = false;

        while (!y.isZero()) {
            const remainder = try mod(
                &x,
                &y,
                allocator,
            );

            x.deinit();

            x = y;
            y = remainder;
        }

        y.deinit();

        return x;
    }

    pub fn writeValue(
        self: *const BigInt,
        io: *const std.Io,
    ) !void {
        const stdout = std.Io.File.stdout();

        if (self.isZero()) {
            try stdout.writePositionalAll(io.*, "0", 0);
            return;
        }

        var buffer: [64]u8 = undefined; // TODO: review
        var writer = std.Io.Writer.fixed(&buffer);

        if (self.negative)
            try writer.writeByte('-');

        var index = self.limbs.items.len;

        while (index > 0) {
            index -= 1;

            const limb = self.limbs.items[index];

            if (index == self.limbs.items.len - 1) {
                try writer.print("{}", .{limb});
            } else {
                try writer.print("{:0>20}", .{limb});
            }
        }

        try stdout.writePositionalAll(
            io.*,
            writer.buffered(),
            0,
        );
    }
};
