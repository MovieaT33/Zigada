const std = @import("std");

const Rational = @import("rational.zig").Rational;

const Allocator = std.mem.Allocator;

pub const RationalRegistry = struct {
    const Self = @This();

    rationals: std.ArrayList(Rational),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return .{
            .rationals = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.rationals.items) |*rational|
            rational.deinit();

        self.rationals.deinit(self.allocator);
    }

    pub fn adopt(
        self: *Self,
        rational: Rational,
    ) Allocator.Error!void {
        try self.rationals.append(
            self.allocator,
            rational,
        );
    }
};
