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

    pub fn cmp(a: *const Self, b: *const Self) std.math.Order {
        if (a.negative != b.negative)
            return if (a.negative) .lt else .gt;

        const order = cmpAbs(a, b);

        return if (a.negative)
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

    fn cmpAbs(a: *const Self, b: *const Self) std.math.Order {
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
        a: *const Self,
        b: *const Self,
    ) Allocator.Error!Self {
        const alloc = getAllocator();

        var result = init();
        errdefer result.deinit();

        const max_len = @max(
            a.limbs.items.len,
            b.limbs.items.len,
        );

        try result.limbs.ensureTotalCapacity(alloc, max_len + 1);

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

            try result.limbs.append(alloc, @truncate(sum));

            carry = sum >> 64;
        }

        if (carry != 0)
            try result.limbs.append(alloc, @truncate(carry));

        return result;
    }

    fn subAbs(
        a: *const Self,
        b: *const Self,
    ) Allocator.Error!Self {
        const alloc = getAllocator();

        var result = init();
        errdefer result.deinit();

        try result.limbs.ensureTotalCapacity(alloc, a.limbs.items.len);

        var borrow: Wide = 0;

        for (0..a.limbs.items.len) |i| {
            const av: Wide = a.limbs.items[i];

            const bv: Wide = if (i < b.limbs.items.len)
                b.limbs.items[i]
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
        a: *const Self,
        b: *const Self,
    ) Allocator.Error!Self {
        if (a.isZero())
            return try b.clone();

        if (b.isZero())
            return try a.clone();

        if (a.negative == b.negative) {
            var result = try addAbs(a, b);
            result.negative = a.negative;
            return result;
        }

        return switch (cmpAbs(a, b)) {
            .eq => init(),
            .gt => blk: {
                var result = try subAbs(a, b);
                result.negative = a.negative;
                break :blk result;
            },
            .lt => blk: {
                var result = try subAbs(b, a);
                result.negative = b.negative;
                break :blk result;
            },
        };
    }

    pub fn mul(
        a: *const Self,
        b: *const Self,
    ) Allocator.Error!Self {
        const alloc = getAllocator();

        var result = init();
        errdefer result.deinit();

        if (a.isZero() or b.isZero())
            return result;

        const len =
            a.limbs.items.len +
            b.limbs.items.len;

        try result.limbs.resize(alloc, len);
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

    pub fn mod(a: *const Self, b: *const Self) !Self {
        const alloc = getAllocator();

        if (b.isZero())
            return error.DivisionByZero;

        var divisor = try b.clone();
        errdefer divisor.deinit();

        divisor.negative = false;

        var dividend = try a.clone();
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

    pub fn div(a: *const Self, b: *const Self) !DivResult {
        const alloc = getAllocator();

        if (b.isZero())
            return error.DivisionByZero;

        var quotient = init();
        errdefer quotient.deinit();

        var remainder = init();
        errdefer remainder.deinit();

        if (a.isZero()) {
            return .{
                .quotient = quotient,
                .remainder = remainder,
            };
        }

        var dividend = try a.clone();
        defer dividend.deinit();
        dividend.negative = false;

        var divisor = try b.clone();
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

    pub fn divExact(a: *const Self, b: *const Self) !Self {
        var result = try div(a, b);

        if (!result.remainder.isZero()) {
            result.remainder.deinit();
            result.quotient.deinit();

            return error.NotDivisible;
        }

        result.remainder.deinit();

        return result.quotient;
    }

    pub fn gcd(a: *const Self, b: *const Self) !Self {
        var x = try a.clone();
        errdefer x.deinit();

        var y = try b.clone();
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
