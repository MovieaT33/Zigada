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

    pub fn init(
        numerator: i64,
        denominator: i64,
    ) !*Self {
        const alloc = getAllocator();

        if (denominator == 0)
            return error.DivisionByZero;

        const self = try alloc.create(Self);
        errdefer self.deinit();

        self.* = .{
            .numerator = BigInt.init(alloc),
            .denominator = BigInt.init(alloc),
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

    pub fn deinit(self: *Self) void {
        const alloc = getAllocator();

        self.numerator.deinit();
        self.denominator.deinit();

        alloc.destroy(self);
    }

    pub fn eql(a: *const Self, b: *const Self) bool {
        return try cmp(a, b) == .eq;
    }

    pub fn lessThan(a: *const Self, b: *const Self) !bool {
        return try cmp(a, b) == .lt;
    }

    pub fn greaterThan(a: *const Self, b: *const Self) !bool {
        return try cmp(a, b) == .gt;
    }

    pub fn cmp(
        a: *const Self,
        b: *const Self,
    ) !std.math.Order {
        const alloc = getAllocator();

        var left = try BigInt.mul(
            alloc,
            &a.numerator,
            &b.denominator,
        );
        defer left.deinit();

        var right = try BigInt.mul(
            alloc,
            &b.numerator,
            &a.denominator,
        );
        defer right.deinit();

        return BigInt.cmp(&left, &right);
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
        const alloc = getAllocator();

        var divisor: BigInt = try .gcd(
            alloc,
            &self.numerator,
            &self.denominator,
        );
        defer divisor.deinit();

        if (divisor.isOne())
            return;

        var numerator: BigInt = try .divExact(
            alloc,
            &self.numerator,
            &divisor,
        );
        errdefer numerator.deinit();

        var denominator: BigInt = try .divExact(
            alloc,
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
        a: *const Self,
        b: *const Self,
    ) !*Self {
        const alloc = getAllocator();

        var numerator: BigInt = switch (operation) {
            .add, .sub => blk: {
                var left: BigInt = try .mul(
                    alloc,
                    &a.numerator,
                    &b.denominator,
                );
                defer left.deinit();

                var right: BigInt = try .mul(
                    alloc,
                    &b.numerator,
                    &a.denominator,
                );
                defer right.deinit();

                if (operation == .sub)
                    right.negate();

                break :blk try .add(
                    alloc,
                    &left,
                    &right,
                );
            },

            .mul, .div => try .mul(
                alloc,
                &a.numerator,
                if (operation == .mul)
                    &b.numerator
                else
                    &b.denominator,
            ),
        };
        errdefer numerator.deinit();

        var denominator: BigInt = switch (operation) {
            .add, .sub, .mul => try .mul(
                alloc,
                &a.denominator,
                &b.denominator,
            ),

            .div => try .mul(
                alloc,
                &a.denominator,
                &b.numerator,
            ),
        };
        errdefer denominator.deinit();

        if (operation == .div and denominator.negative) {
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

    pub fn add(a: *const Self, b: *const Self) !*Self {
        return operate(.add, a, b);
    }

    pub fn sub(a: *const Self, b: *const Self) !*Self {
        return operate(.sub, a, b);
    }

    pub fn mul(a: *const Self, b: *const Self) !*Self {
        return operate(.mul, a, b);
    }

    pub fn div(a: *const Self, b: *const Self) !*Self {
        if (b.numerator.isZero())
            return error.DivisionByZero;

        return operate(.div, a, b);
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
        return allocator orelse unreachable;
    }
};
