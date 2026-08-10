// Created by ChatGPT
const std = @import("std");

const BigInt = @import("big_int.zig").BigInt;

const Allocator = std.mem.Allocator;

pub const Rational = struct {
    const Self = @This();

    pub const Type = Self;

    numerator: BigInt,
    denominator: BigInt,
    allocator: Allocator,

    pub fn init(
        numerator: i64,
        denominator: i64,
        allocator: Allocator,
    ) !Self {
        if (denominator == 0)
            return error.DivisionByZero;

        var self = Self{
            .numerator = BigInt.init(allocator),
            .denominator = BigInt.init(allocator),
            .allocator = allocator,
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

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.numerator.deinit();
        self.denominator.deinit();
    }

    fn clone(self: *const Self) !Self {
        var copy = Self{
            .numerator = undefined,
            .denominator = undefined,
            .allocator = self.allocator,
        };
        errdefer copy.deinit();

        copy.numerator =
            try self.numerator.clone(self.allocator);

        copy.denominator =
            try self.denominator.clone(self.allocator);

        return copy;
    }

    fn normalize(self: *Self) !void {
        self.numerator.normalize();
        self.denominator.normalize();

        if (self.numerator.isZero()) {
            try self.denominator.setUnsigned(1);
            return;
        }

        self.denominator.negative = false;

        // TODO: gcd(numerator, denominator).
    }

    pub fn add(a: Self, b: Self) !Self {
        var ad = try BigInt.mul(
            &a.numerator,
            &b.denominator,
            a.allocator,
        );
        defer ad.deinit();

        var cb = try BigInt.mul(
            &b.numerator,
            &a.denominator,
            a.allocator,
        );
        defer cb.deinit();

        var numerator = try BigInt.add(
            &ad,
            &cb,
            a.allocator,
        );
        errdefer numerator.deinit();

        var denominator = try BigInt.mul(
            &a.denominator,
            &b.denominator,
            a.allocator,
        );
        errdefer denominator.deinit();

        var result = Self{
            .numerator = numerator,
            .denominator = denominator,
            .allocator = a.allocator,
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
        var numerator = try BigInt.mul(
            &a.numerator,
            &b.numerator,
            a.allocator,
        );
        errdefer numerator.deinit();

        var denominator = try BigInt.mul(
            &a.denominator,
            &b.denominator,
            a.allocator,
        );
        errdefer denominator.deinit();

        var result = Self{
            .numerator = numerator,
            .denominator = denominator,
            .allocator = a.allocator,
        };

        try result.normalize();
        return result;
    }

    pub fn div(a: Self, b: Self) !Self {
        if (b.numerator.isZero())
            return error.DivisionByZero;

        var numerator = try BigInt.mul(
            &a.numerator,
            &b.denominator,
            a.allocator,
        );
        errdefer numerator.deinit();

        var denominator = try BigInt.mul(
            &a.denominator,
            &b.numerator,
            a.allocator,
        );
        errdefer denominator.deinit();

        if (denominator.negative) {
            denominator.negate();
            numerator.negate();
        }

        var result = Self{
            .numerator = numerator,
            .denominator = denominator,
            .allocator = a.allocator,
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
