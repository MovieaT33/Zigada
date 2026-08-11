// Checked style

const std = @import("std");

const UnitExpression = @import("unit_expression.zig").UnitExpression;

const Allocator = std.mem.Allocator;

pub const UnitRegistry = struct {
    const Self = @This();

    allocator: Allocator,
    expressions: std.ArrayList(*UnitExpression),

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .expressions = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.expressions.items) |expression|
            expression.deinit();

        self.expressions.deinit(self.allocator);
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

    pub fn exists(self: *const Self, expression: UnitExpression) bool {
        return self.find(expression) != null;
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
