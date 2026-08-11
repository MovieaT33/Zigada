// Created by ChatGPT

const std = @import("std");

const BigInt = @import("big_int.zig").BigInt;
const RationalRegistry = @import("rational_registry.zig").RationalRegistry;

const Allocator = std.mem.Allocator;

pub const Error = error{
    MissingAllocator,
};

pub const Rational = struct {
    const Self = @This();

    pub const Type = Self;

    pub var rational_registry: ?*RationalRegistry = undefined;
    pub var allocator: ?Allocator = undefined;

    numerator: BigInt,
    denominator: BigInt,

    pub fn init(numerator: i64, denominator: i64) !Self {
        if (denominator == 0)
            return error.DivisionByZero;

        if (allocator == null)
            return error.MissingAllocator;

        var self = Self{
            .numerator = BigInt.init(allocator.?),
            .denominator = BigInt.init(allocator.?),
        };
        errdefer self.deinit();

        try self.numerator.setSigned(numerator);

        const denominator_abs: u64 = if (denominator < 0)
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
        self.numerator.deinit();
        self.denominator.deinit();
    }

    fn clone(self: *const Self) !Self {
        if (allocator == null)
            return error.MissingAllocator;

        var copy = Self{
            .numerator = undefined,
            .denominator = undefined,
        };
        errdefer copy.deinit();

        copy.numerator =
            try self.numerator.clone(allocator.?);

        copy.denominator =
            try self.denominator.clone(allocator.?);

        return copy;
    }

    fn normalize(self: *Self) !void {
        if (allocator == null)
            return error.MissingAllocator;

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
            allocator.?,
        );
        defer divisor.deinit();

        if (divisor.isOne())
            return;

        var new_numerator = try BigInt.divExact(
            &self.numerator,
            &divisor,
            allocator.?,
        );
        errdefer new_numerator.deinit();

        var new_denominator = try BigInt.divExact(
            &self.denominator,
            &divisor,
            allocator.?,
        );
        errdefer new_denominator.deinit();

        self.numerator.deinit();
        self.denominator.deinit();

        self.numerator = new_numerator;
        self.denominator = new_denominator;
    }

    pub fn add(a: Self, b: Self) !Self {
        if (allocator == null)
            return error.MissingAllocator;

        var ad = try BigInt.mul(
            &a.numerator,
            &b.denominator,
            allocator.?,
        );
        defer ad.deinit();

        var cb = try BigInt.mul(
            &b.numerator,
            &a.denominator,
            allocator.?,
        );
        defer cb.deinit();

        var numerator = try BigInt.add(
            &ad,
            &cb,
            allocator.?,
        );
        errdefer numerator.deinit();

        var denominator = try BigInt.mul(
            &a.denominator,
            &b.denominator,
            allocator.?,
        );
        errdefer denominator.deinit();

        var result = Self{
            .numerator = numerator,
            .denominator = denominator,
        };

        try result.normalize();
        return result;
    }

    pub fn sub(a: Self, b: Self) !Self {
        var neg_b = try b.clone();
        defer neg_b.deinit();

        neg_b.numerator.negate();

        return Self.add(a, neg_b);
    }

    pub fn mul(a: Self, b: Self) !Self {
        if (allocator == null)
            return error.MissingAllocator;

        var numerator = try BigInt.mul(
            &a.numerator,
            &b.numerator,
            allocator.?,
        );
        errdefer numerator.deinit();

        var denominator = try BigInt.mul(
            &a.denominator,
            &b.denominator,
            allocator.?,
        );
        errdefer denominator.deinit();

        var result = Self{
            .numerator = numerator,
            .denominator = denominator,
        };

        try result.normalize();
        return result;
    }

    pub fn div(a: Self, b: Self) !Self {
        if (allocator == null)
            return error.MissingAllocator;

        if (b.numerator.isZero())
            return error.DivisionByZero;

        var numerator = try BigInt.mul(
            &a.numerator,
            &b.denominator,
            allocator.?,
        );
        errdefer numerator.deinit();

        var denominator = try BigInt.mul(
            &a.denominator,
            &b.numerator,
            allocator.?,
        );
        errdefer denominator.deinit();

        if (denominator.negative) {
            denominator.negate();
            numerator.negate();
        }

        var result = Self{
            .numerator = numerator,
            .denominator = denominator,
        };

        try result.normalize();
        return result;
    }

    pub fn writeValue(
        self: *const Self,
        io: *const std.Io,
        _: ?[]const u8,
    ) !void {
        try self.numerator.writeValue(io);

        const stdout = std.Io.File.stdout();
        try stdout.writePositionalAll(io.*, "/", 0);

        try self.denominator.writeValue(io);
    }
};
