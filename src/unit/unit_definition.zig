const std = @import("std");

const Operation = @import("../operation.zig").Operation;
const UnitExpression = @import("unit_expression.zig").UnitExpression;

const Allocator = std.mem.Allocator;

pub fn UnitDefinition(comptime N: type) type {
    const T = N.T;

    return struct {
        const Self = @This();

        pub const Constraint = struct {
            min: ?*T = null,
            max: ?*T = null,

            pub fn init(min: ?*T, max: ?*T) @This() {
                return .{
                    .min = min,
                    .max = max,
                };
            }

            pub fn validate(self: *const @This(), value: *const T) !void {
                if (self.min) |min|
                    if (try value.lessThan(min))
                        return error.BelowMinimum;

                if (self.max) |max|
                    if (try value.greaterThan(max))
                        return error.AboveMaximum;
            }
        };

        pub var allocator: ?Allocator = null;

        expression: *UnitExpression,
        constraint: Constraint,

        pub fn init(
            expression: *UnitExpression,
            constraint: Constraint,
        ) Allocator.Error!*Self {
            const alloc = allocator orelse unreachable;

            const self = try alloc.create(Self);

            self.* = .{
                .expression = expression,
                .constraint = constraint,
            };

            return self;
        }

        pub fn deinit(self: *Self) void {
            const alloc = allocator orelse unreachable;

            self.expression.deinit();
            alloc.destroy(self);
        }

        pub fn mul(
            comptime cross_cancellation: bool,
            left: *const Self,
            right: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) Allocator.Error!*Self {
            return combine(
                .mul,
                cross_cancellation,
                left,
                right,
                constraint,
                name,
            );
        }

        pub fn div(
            comptime cross_cancellation: bool,
            left: *const Self,
            right: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) Allocator.Error!*Self {
            return combine(
                .div,
                cross_cancellation,
                left,
                right,
                constraint,
                name,
            );
        }

        pub fn combine(
            comptime operation: Operation,
            comptime cross_cancellation: bool,
            left: *const Self,
            right: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) Allocator.Error!*Self {
            const expression: *UnitExpression = try .combine(
                operation,
                cross_cancellation,
                left.expression,
                right.expression,
                name,
            );
            errdefer expression.deinit();

            return .init(expression, constraint);
        }
    };
}
