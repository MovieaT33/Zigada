const std = @import("std");

const BigInt = @import("big_int.zig").BigInt;
const RationalRegistry = @import("rational_registry.zig").RationalRegistry;

const Allocator = std.mem.Allocator;

pub const Rational = struct {
    const Self = @This();

    pub const T = Self;

    pub var allocator: ?Allocator = null;
    pub var rational_registry: ?*RationalRegistry = null;

    numerator: BigInt,
    denominator: BigInt,

    pub fn init(
        numerator: i64,
        denominator: i64,
    ) !*Self {
        if (denominator == 0)
            return error.DivisionByZero;

        const alloc = allocator orelse unreachable;

        const self = try alloc.create(Self);

        self.* = .{
            .numerator = BigInt.init(alloc),
            .denominator = BigInt.init(alloc),
        };
        errdefer self.deinit();

        try self.numerator.setSigned(numerator);

        const denominator_abs: u64 =
            if (denominator < 0)
                @as(u64, @intCast(-(denominator + 1))) + 1
            else
                @intCast(denominator);

        try self.denominator.setUnsigned(denominator_abs);

        if (denominator < 0)
            self.numerator.negate();

        try self.normalize();

        if (rational_registry) |registry|
            try registry.adopt(self);

        return self;
    }

    pub fn deinit(self: *Self) void {
        const alloc = allocator orelse unreachable;

        self.numerator.deinit();
        self.denominator.deinit();

        alloc.destroy(self);
    }

    fn clone(self: *const Self) !*Self {
        const alloc = allocator orelse unreachable;

        const copy = try alloc.create(Self);
        errdefer alloc.destroy(copy);

        copy.* = .{
            .numerator = undefined,
            .denominator = undefined,
        };

        errdefer {
            copy.numerator.deinit();
            copy.denominator.deinit();
        }

        copy.numerator = try self.numerator.clone(alloc);
        copy.denominator = try self.denominator.clone(alloc);

        return copy;
    }

    fn normalize(self: *Self) !void {
        const alloc = allocator orelse unreachable;

        self.numerator.normalize();
        self.denominator.normalize();

        if (self.numerator.isZero()) {
            try self.denominator.setUnsigned(1);
            return;
        }

        if (self.denominator.negative) {
            self.denominator.negate();
            self.numerator.negate();
        }

        var divisor = try BigInt.gcd(
            &self.numerator,
            &self.denominator,
            alloc,
        );
        defer divisor.deinit();

        if (divisor.isOne())
            return;

        var new_numerator = try BigInt.divExact(
            &self.numerator,
            &divisor,
            alloc,
        );
        errdefer new_numerator.deinit();

        var new_denominator = try BigInt.divExact(
            &self.denominator,
            &divisor,
            alloc,
        );
        errdefer new_denominator.deinit();

        self.numerator.deinit();
        self.denominator.deinit();

        self.numerator = new_numerator;
        self.denominator = new_denominator;
    }

    fn bigIntEql(
        a: *const BigInt,
        b: *const BigInt,
    ) bool {
        if (a.negative != b.negative)
            return false;

        if (a.limbs.items.len != b.limbs.items.len)
            return false;

        for (a.limbs.items, b.limbs.items) |a_limb, b_limb| {
            if (a_limb != b_limb)
                return false;
        }

        return true;
    }

    pub fn eql(
        a: *const Self,
        b: *const Self,
    ) bool {
        return bigIntEql(
            &a.numerator,
            &b.numerator,
        ) and bigIntEql(
            &a.denominator,
            &b.denominator,
        );
    }

    pub fn lessThan(
        a: *const Self,
        b: *const Self,
    ) !bool {
        const alloc = allocator orelse unreachable;

        var left = try BigInt.mul(
            &a.numerator,
            &b.denominator,
            alloc,
        );
        defer left.deinit();

        var right = try BigInt.mul(
            &b.numerator,
            &a.denominator,
            alloc,
        );
        defer right.deinit();

        return BigInt.cmp(&left, &right) == .lt;
    }

    pub fn greaterThan(
        a: *const Self,
        b: *const Self,
    ) !bool {
        const alloc = allocator orelse unreachable;

        var left = try BigInt.mul(
            &a.numerator,
            &b.denominator,
            alloc,
        );
        defer left.deinit();

        var right = try BigInt.mul(
            &b.numerator,
            &a.denominator,
            alloc,
        );
        defer right.deinit();

        return BigInt.cmp(&left, &right) == .gt;
    }

    pub fn add(
        a: *const Self,
        b: *const Self,
    ) !*Self {
        const alloc = allocator orelse unreachable;

        var ad = try BigInt.mul(
            &a.numerator,
            &b.denominator,
            alloc,
        );
        defer ad.deinit();

        var cb = try BigInt.mul(
            &b.numerator,
            &a.denominator,
            alloc,
        );
        defer cb.deinit();

        var numerator = try BigInt.add(
            &ad,
            &cb,
            alloc,
        );
        errdefer numerator.deinit();

        var denominator = try BigInt.mul(
            &a.denominator,
            &b.denominator,
            alloc,
        );
        errdefer denominator.deinit();

        const result = try alloc.create(Self);

        result.* = .{
            .numerator = numerator,
            .denominator = denominator,
        };
        errdefer result.deinit();

        try result.normalize();

        if (rational_registry) |registry|
            try registry.adopt(result);

        return result;
    }

    pub fn sub(
        a: *const Self,
        b: *const Self,
    ) !*Self {
        const alloc = allocator orelse unreachable;

        var numerator = try BigInt.mul(
            &a.numerator,
            &b.denominator,
            alloc,
        );
        defer numerator.deinit();

        var other_numerator = try BigInt.mul(
            &b.numerator,
            &a.denominator,
            alloc,
        );
        defer other_numerator.deinit();

        other_numerator.negate();

        var result_numerator = try BigInt.add(
            &numerator,
            &other_numerator,
            alloc,
        );
        errdefer result_numerator.deinit();

        var denominator = try BigInt.mul(
            &a.denominator,
            &b.denominator,
            alloc,
        );
        errdefer denominator.deinit();

        const result = try alloc.create(Self);

        result.* = .{
            .numerator = result_numerator,
            .denominator = denominator,
        };
        errdefer result.deinit();

        try result.normalize();

        if (rational_registry) |registry|
            try registry.adopt(result);

        return result;
    }

    pub fn mul(
        a: *const Self,
        b: *const Self,
    ) !*Self {
        const alloc = allocator orelse unreachable;

        var numerator = try BigInt.mul(
            &a.numerator,
            &b.numerator,
            alloc,
        );
        errdefer numerator.deinit();

        var denominator = try BigInt.mul(
            &a.denominator,
            &b.denominator,
            alloc,
        );
        errdefer denominator.deinit();

        const result = try alloc.create(Self);

        result.* = .{
            .numerator = numerator,
            .denominator = denominator,
        };
        errdefer result.deinit();

        try result.normalize();

        if (rational_registry) |registry|
            try registry.adopt(result);

        return result;
    }

    pub fn div(
        a: *const Self,
        b: *const Self,
    ) !*Self {
        const alloc = allocator orelse unreachable;

        if (b.numerator.isZero())
            return error.DivisionByZero;

        var numerator = try BigInt.mul(
            &a.numerator,
            &b.denominator,
            alloc,
        );
        errdefer numerator.deinit();

        var denominator = try BigInt.mul(
            &a.denominator,
            &b.numerator,
            alloc,
        );
        errdefer denominator.deinit();

        if (denominator.negative) {
            denominator.negate();
            numerator.negate();
        }

        const result = try alloc.create(Self);

        result.* = .{
            .numerator = numerator,
            .denominator = denominator,
        };
        errdefer result.deinit();

        try result.normalize();

        if (rational_registry) |registry|
            try registry.adopt(result);

        return result;
    }

    pub fn writeValue(
        self: *const Self,
        io: *const std.Io,
    ) !void {
        try self.numerator.writeValue(io);

        const stdout: std.Io.File = .stdout();

        try stdout.writePositionalAll(
            io.*,
            "/",
            0,
        );

        try self.denominator.writeValue(io);
    }
};
