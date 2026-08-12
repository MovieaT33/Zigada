const std = @import("std");

const Operation = @import("../operation.zig").Operation;
const BigInt = @import("big_int.zig").BigInt;
const RationalRegistry = @import("rational_registry.zig").RationalRegistry;

const Allocator = std.mem.Allocator;

pub const Rational = struct {
    const Self = @This();

    pub var allocator: ?Allocator = null;
    pub var rational_registry: ?*RationalRegistry = null;

    numerator: BigInt,
    denominator: BigInt,

    pub fn init(numerator: i64, denominator: i64) !*Self {
        const _allocator = getAllocator();

        if (denominator == 0)
            return error.DivisionByZero;

        const self = try _allocator.create(Self);
        errdefer self.deinit();

        self.* = .{
            .numerator = .init(),
            .denominator = .init(),
        };

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

    pub fn fromBigInts(numerator: BigInt, denominator: BigInt) !*Self {
        const _allocator = getAllocator();

        const rational = try _allocator.create(Self);
        errdefer rational.deinit();

        rational.* = .{
            .numerator = numerator,
            .denominator = denominator,
        };

        try rational.normalize();

        if (rational_registry) |registry|
            try registry.adopt(rational);

        return rational;
    }

    pub fn deinit(self: *Self) void {
        const _allocator = getAllocator();

        self.numerator.deinit();
        self.denominator.deinit();

        _allocator.destroy(self);
    }

    pub fn clone(self: *const Self) !*Self {
        var numerator = try self.numerator.clone();
        errdefer numerator.deinit();

        var denominator = try self.denominator.clone();
        errdefer denominator.deinit();

        return fromBigInts(
            numerator,
            denominator,
        );
    }

    pub fn cmp(
        lhs: *const Self,
        rhs: *const Self,
    ) Allocator.Error!std.math.Order {
        var lhs_product: BigInt = try .mul(
            &lhs.numerator,
            &rhs.denominator,
        );
        defer lhs_product.deinit();

        var rhs_product: BigInt = try .mul(
            &rhs.numerator,
            &lhs.denominator,
        );
        defer rhs_product.deinit();

        return BigInt.cmp(&lhs_product, &rhs_product);
    }

    pub fn eql(
        lhs: *const Self,
        rhs: *const Self,
    ) Allocator.Error!bool {
        return try cmp(lhs, rhs) == .eq;
    }

    pub fn lessThan(
        lhs: *const Self,
        rhs: *const Self,
    ) Allocator.Error!bool {
        return try cmp(lhs, rhs) == .lt;
    }

    pub fn greaterThan(
        lhs: *const Self,
        rhs: *const Self,
    ) Allocator.Error!bool {
        return try cmp(lhs, rhs) == .gt;
    }

    fn normalize(self: *Self) !void {
        self.numerator.normalize();
        self.denominator.normalize();

        if (self.numerator.isZero()) {
            try self.denominator.setUnsigned(1);
            return;
        }

        self.normalizeSign();
        try self.reduce();
    }

    fn normalizeSign(self: *Self) void {
        if (self.denominator.negative) {
            self.denominator.negate();
            self.numerator.negate();
        }
    }

    fn reduce(self: *Self) !void {
        var divisor: BigInt = try .gcd(
            &self.numerator,
            &self.denominator,
        );
        defer divisor.deinit();

        if (divisor.isOne())
            return;

        var numerator: BigInt = try .divExact(
            &self.numerator,
            &divisor,
        );
        errdefer numerator.deinit();

        var denominator: BigInt = try .divExact(
            &self.denominator,
            &divisor,
        );
        errdefer denominator.deinit();

        self.numerator.deinit();
        self.denominator.deinit();

        self.numerator = numerator;
        self.denominator = denominator;
    }

    fn operate(
        comptime operation: Operation,
        lhs: *const Self,
        rhs: *const Self,
    ) !*Self {
        if (operation == .div and rhs.numerator.isZero())
            return error.DivisionByZero;

        var numerator: BigInt = switch (operation) {
            .add, .sub => blk: {
                var lhs_product: BigInt = try .mul(
                    &lhs.numerator,
                    &rhs.denominator,
                );
                defer lhs_product.deinit();

                var rhs_product: BigInt = try .mul(
                    &rhs.numerator,
                    &lhs.denominator,
                );
                defer rhs_product.deinit();

                if (operation == .sub)
                    rhs_product.negate();

                break :blk try .add(
                    &lhs_product,
                    &rhs_product,
                );
            },

            .mul, .div => try .mul(
                &lhs.numerator,
                if (operation == .mul)
                    &rhs.numerator
                else
                    &rhs.denominator,
            ),
        };
        errdefer numerator.deinit();

        var denominator: BigInt = switch (operation) {
            .add, .sub, .mul => try .mul(
                &lhs.denominator,
                &rhs.denominator,
            ),

            .div => try .mul(
                &lhs.denominator,
                &rhs.numerator,
            ),
        };
        errdefer denominator.deinit();

        if (operation == .div and denominator.negative) {
            denominator.negate();
            numerator.negate();
        }

        return fromBigInts(
            numerator,
            denominator,
        );
    }

    pub fn add(lhs: *const Self, rhs: *const Self) !*Self {
        return operate(.add, lhs, rhs);
    }

    pub fn sub(lhs: *const Self, rhs: *const Self) !*Self {
        return operate(.sub, lhs, rhs);
    }

    pub fn mul(lhs: *const Self, rhs: *const Self) !*Self {
        return operate(.mul, lhs, rhs);
    }

    pub fn div(lhs: *const Self, rhs: *const Self) !*Self {
        return operate(.div, lhs, rhs);
    }

    pub fn write(
        self: *const Self,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try self.numerator.write(writer);

        if (!self.denominator.isOne()) {
            try writer.writeByte('/');
            try self.denominator.write(writer);
        }
    }

    fn getAllocator() Allocator {
        return allocator orelse unreachable; // Allocator must be initialized
    }
};
