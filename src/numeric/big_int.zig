const std = @import("std");

const Allocator = std.mem.Allocator;

pub const BigInt = struct {
    const Self = @This();

    const Limb = u64;
    const Wide = u128;

    pub const DivResult = struct {
        quotient: Self,
        remainder: Self,
    };

    pub var allocator: ?Allocator = null;

    negative: bool,
    limbs: std.ArrayList(Limb),

    pub fn init() Self {
        return .{
            .negative = false,
            .limbs = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        const alloc = getAllocator();
        self.limbs.deinit(alloc);
    }

    pub fn clone(self: *const Self) Allocator.Error!Self {
        const alloc = getAllocator();

        var result = init();
        errdefer result.deinit();

        result.negative = self.negative;

        try result.limbs.appendSlice(alloc, self.limbs.items);

        return result;
    }

    pub fn isZero(self: *const Self) bool {
        return self.limbs.items.len == 0;
    }

    pub fn isOne(self: *const Self) bool {
        return !self.negative and
            self.limbs.items.len == 1 and
            self.limbs.items[0] == 1;
    }

    pub fn cmp(lhs: *const Self, rhs: *const Self) std.math.Order {
        if (lhs.negative != rhs.negative)
            return if (lhs.negative) .lt else .gt;

        const order = cmpAbs(lhs, rhs);

        return if (lhs.negative)
            switch (order) {
                .lt => .gt,
                .eq => .eq,
                .gt => .lt,
            }
        else
            order;
    }

    pub fn normalize(self: *Self) void {
        while (self.limbs.items.len > 0 and
            self.limbs.items[self.limbs.items.len - 1] == 0)
        {
            _ = self.limbs.pop();
        }

        if (self.isZero())
            self.negative = false;
    }

    pub fn setUnsigned(
        self: *Self,
        value: Limb,
    ) Allocator.Error!void {
        const alloc = getAllocator();

        self.limbs.clearRetainingCapacity();
        self.negative = false;

        if (value == 0)
            return;

        try self.limbs.append(alloc, value);
    }

    pub fn setSigned(
        self: *Self,
        value: i64,
    ) Allocator.Error!void {
        const magnitude: u64 = if (value < 0)
            @as(u64, @intCast(-(value + 1))) + 1
        else
            @intCast(value);

        self.negative = value < 0;

        try self.setUnsigned(magnitude);
        self.negative = value < 0 and !self.isZero();
    }

    pub fn negate(self: *Self) void {
        if (!self.isZero())
            self.negative = !self.negative;
    }

    fn cmpAbs(lhs: *const Self, rhs: *const Self) std.math.Order {
        if (lhs.limbs.items.len < rhs.limbs.items.len)
            return .lt;

        if (lhs.limbs.items.len > rhs.limbs.items.len)
            return .gt;

        var i = lhs.limbs.items.len;

        while (i > 0) {
            i -= 1;

            if (lhs.limbs.items[i] < rhs.limbs.items[i])
                return .lt;

            if (lhs.limbs.items[i] > rhs.limbs.items[i])
                return .gt;
        }

        return .eq;
    }

    fn addAbs(
        lhs: *const Self,
        rhs: *const Self,
    ) Allocator.Error!Self {
        const alloc = getAllocator();

        var result = init();
        errdefer result.deinit();

        const max_len = @max(
            lhs.limbs.items.len,
            rhs.limbs.items.len,
        );

        try result.limbs.ensureTotalCapacity(alloc, max_len + 1);

        var carry: Wide = 0;

        for (0..max_len) |i| {
            const av: Wide = if (i < lhs.limbs.items.len)
                lhs.limbs.items[i]
            else
                0;

            const bv: Wide = if (i < rhs.limbs.items.len)
                rhs.limbs.items[i]
            else
                0;

            const sum = av + bv + carry;

            try result.limbs.append(alloc, @truncate(sum));

            carry = sum >> 64;
        }

        if (carry != 0)
            try result.limbs.append(alloc, @truncate(carry));

        return result;
    }

    fn subAbs(
        lhs: *const Self,
        rhs: *const Self,
    ) Allocator.Error!Self {
        const alloc = getAllocator();

        var result = init();
        errdefer result.deinit();

        try result.limbs.ensureTotalCapacity(alloc, lhs.limbs.items.len);

        var borrow: Wide = 0;

        for (0..lhs.limbs.items.len) |i| {
            const av: Wide = lhs.limbs.items[i];

            const bv: Wide = if (i < rhs.limbs.items.len)
                rhs.limbs.items[i]
            else
                0;

            const subtrahend = bv + borrow;

            if (av >= subtrahend) {
                try result.limbs.append(alloc, @truncate(av - subtrahend));
                borrow = 0;
            } else {
                const value =
                    (@as(Wide, 1) << 64) + av - subtrahend;

                try result.limbs.append(alloc, @truncate(value));
                borrow = 1;
            }
        }

        result.normalize();
        return result;
    }

    pub fn add(
        lhs: *const Self,
        rhs: *const Self,
    ) Allocator.Error!Self {
        if (lhs.isZero())
            return try lhs.clone();

        if (rhs.isZero())
            return try lhs.clone();

        if (lhs.negative == rhs.negative) {
            var result = try addAbs(lhs, rhs);
            result.negative = lhs.negative;
            return result;
        }

        return switch (cmpAbs(lhs, rhs)) {
            .eq => init(),
            .gt => blk: {
                var result = try subAbs(lhs, rhs);
                result.negative = lhs.negative;
                break :blk result;
            },
            .lt => blk: {
                var result = try subAbs(rhs, rhs);
                result.negative = rhs.negative;
                break :blk result;
            },
        };
    }

    pub fn mul(
        lhs: *const Self,
        rhs: *const Self,
    ) Allocator.Error!Self {
        const alloc = getAllocator();

        var result = init();
        errdefer result.deinit();

        if (lhs.isZero() or rhs.isZero())
            return result;

        const len =
            lhs.limbs.items.len +
            rhs.limbs.items.len;

        try result.limbs.resize(alloc, len);
        @memset(result.limbs.items, 0);

        for (lhs.limbs.items, 0..) |av, i| {
            var carry: Wide = 0;

            for (rhs.limbs.items, 0..) |bv, j| {
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

            var index = i + rhs.limbs.items.len;

            while (carry != 0) {
                const sum =
                    @as(Wide, result.limbs.items[index]) +
                    carry;

                result.limbs.items[index] = @truncate(sum);
                carry = sum >> 64;
                index += 1;
            }
        }

        result.negative = lhs.negative != rhs.negative;
        result.normalize();

        return result;
    }

    pub fn mod(lhs: *const Self, rhs: *const Self) !Self {
        const alloc = getAllocator();

        if (rhs.isZero())
            return error.DivisionByZero;

        var divisor = try rhs.clone();
        errdefer divisor.deinit();

        divisor.negative = false;

        var dividend = try lhs.clone();
        errdefer dividend.deinit();

        dividend.negative = false;

        var result = init();
        errdefer result.deinit();

        if (dividend.isZero())
            return result;

        if (cmpAbs(&dividend, &divisor) == .lt) {
            divisor.deinit();
            return dividend;
        }

        try result.limbs.ensureTotalCapacity(alloc, divisor.limbs.items.len);

        var limb_index = dividend.limbs.items.len;

        while (limb_index > 0) {
            limb_index -= 1;

            const limb = dividend.limbs.items[limb_index];

            var bit_index: u7 = 64;

            while (bit_index > 0) {
                bit_index -= 1;

                try shiftLeftOne(&result);

                if (((limb >> @as(u6, @intCast(bit_index))) & 1) != 0)
                    try addOne(&result);

                if (cmpAbs(&result, &divisor) != .lt)
                    subAbsInPlace(&result, &divisor);
            }
        }

        dividend.deinit();
        divisor.deinit();

        return result;
    }

    fn shiftLeftOne(self: *Self) Allocator.Error!void {
        const alloc = getAllocator();

        if (self.isZero())
            return;

        var carry: Limb = 0;

        for (self.limbs.items) |*limb| {
            const old = limb.*;

            limb.* = (old << 1) | carry;
            carry = old >> 63;
        }

        if (carry != 0)
            try self.limbs.append(alloc, carry);
    }

    fn addOne(self: *Self) Allocator.Error!void {
        const alloc = getAllocator();

        if (self.isZero()) {
            try self.limbs.append(alloc, 1);
            return;
        }

        for (self.limbs.items) |*limb| {
            limb.* +%= 1;

            if (limb.* != 0)
                return;
        }

        try self.limbs.append(alloc, 1);
    }

    fn subAbsInPlace(self: *Self, other: *const Self) void {
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

    pub fn div(lhs: *const Self, rhs: *const Self) !DivResult {
        const alloc = getAllocator();

        if (rhs.isZero())
            return error.DivisionByZero;

        var quotient = init();
        errdefer quotient.deinit();

        var remainder = init();
        errdefer remainder.deinit();

        if (lhs.isZero()) {
            return .{
                .quotient = quotient,
                .remainder = remainder,
            };
        }

        var dividend = try lhs.clone();
        defer dividend.deinit();
        dividend.negative = false;

        var divisor = try rhs.clone();
        defer divisor.deinit();
        divisor.negative = false;

        if (cmpAbs(&dividend, &divisor) == .lt) {
            remainder = try dividend.clone();

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

        try quotient.limbs.resize(alloc, (bit_count + 63) / 64);
        @memset(quotient.limbs.items, 0);

        var bit_index = bit_count;

        while (bit_index > 0) {
            bit_index -= 1;

            try shiftLeftOne(&remainder);

            const limb_index = bit_index / 64;
            const bit_in_limb: u6 =
                @intCast(bit_index % 64);

            const bit =
                (dividend.limbs.items[limb_index] >>
                    bit_in_limb) & 1;

            if (bit != 0) {
                try addOne(&remainder);
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
            lhs.negative != rhs.negative and
            !quotient.isZero();

        remainder.negative =
            lhs.negative and
            !remainder.isZero();

        return .{
            .quotient = quotient,
            .remainder = remainder,
        };
    }

    pub fn divExact(lhs: *const Self, rhs: *const Self) !Self {
        var result = try div(lhs, rhs);

        if (!result.remainder.isZero()) {
            result.remainder.deinit();
            result.quotient.deinit();

            return error.NotDivisible;
        }

        result.remainder.deinit();

        return result.quotient;
    }

    pub fn gcd(lhs: *const Self, rhs: *const Self) !Self {
        var x = try lhs.clone();
        errdefer x.deinit();

        var y = try rhs.clone();
        errdefer y.deinit();

        x.negative = false;
        y.negative = false;

        while (!y.isZero()) {
            const remainder = try mod(&x, &y);

            x.deinit();

            x = y;
            y = remainder;
        }

        y.deinit();

        return x;
    }

    pub fn write(
        self: *const Self,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        if (self.isZero()) {
            try writer.writeByte('0');
            return;
        }

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
    }

    fn getAllocator() Allocator {
        return allocator orelse unreachable;
    }
};
