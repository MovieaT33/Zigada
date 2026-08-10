const std = @import("std");

const UnitExpression = @import("unit_expression.zig").UnitExpression;

const Allocator = std.mem.Allocator;

pub const UnitRegistry = struct {
    const Self = @This();

    expressions: std.ArrayList(*UnitExpression),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return .{
            .expressions = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.expressions.items) |expression|
            expression.deinit();

        self.expressions.deinit(self.allocator);
    }

    pub fn exists(self: *const Self, expression: UnitExpression) bool {
        for (self.expressions.items) |existing| {
            if (existing.eql(expression))
                return true;
        }

        return false;
    }

    pub fn find(
        self: *const Self,
        expression: UnitExpression,
    ) ?*UnitExpression {
        for (self.expressions.items) |existing| {
            if (existing.eql(expression))
                return existing;
        }

        return null;
    }

    pub fn adopt(
        self: *Self,
        expression: *UnitExpression,
        comptime unique: bool,
    ) Allocator.Error!void {
        if (!unique or !self.exists(expression.*))
            try self.expressions.append(self.allocator, expression);
    }

    pub fn write(
        self: *const Self,
        io: *const std.Io,
    ) !void {
        for (self.expressions.items) |expression|
            try expression.write(io);
    }
};
