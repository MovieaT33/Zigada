const std = @import("std");

const Operation = @import("../operation.zig").Operation;
const UnitDefinition = @import("../unit/unit_definition.zig").UnitDefinition;
const QuantityRegistry = @import("quantity_registry.zig").QuantityRegistry;

const Allocator = std.mem.Allocator;

pub fn Quantity(comptime N: type) type {
    const Constraint = UnitDefinition(N).Constraint;

    return struct {
        const Self = @This();

        pub var allocator: ?Allocator = null;
        pub var quantity_registry: ?*QuantityRegistry(N) = null;

        value: *const N,
        definition: *const UnitDefinition(N),

        pub fn init(
            value: *const N,
            definition: *const UnitDefinition(N),
        ) !*Self {
            const alloc = getAllocator();

            try definition.constraint.validate(value);

            const self = try alloc.create(Self);
            errdefer alloc.destroy(self);

            self.* = .{
                .value = value,
                .definition = definition,
            };

            if (quantity_registry) |registry|
                try registry.adopt(self);

            return self;
        }

        pub fn deinit(self: *Self) void {
            const alloc = getAllocator();
            alloc.destroy(self);
        }

        pub fn add(left: *const Self, right: *const Self) !*Self {
            return operate(.add, left, right);
        }

        pub fn sub(left: *const Self, right: *const Self) !*Self {
            return operate(.sub, left, right);
        }

        pub fn scale(left: *const Self, right: *const N) !*Self {
            return scaleValue(.mul, left, right);
        }

        pub fn unscale(left: *const Self, right: *const N) !*Self {
            return scaleValue(.div, left, right);
        }

        pub fn mul(
            comptime cross_cancellation: bool,
            left: *const Self,
            right: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) !*Self {
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
        ) !*Self {
            return combine(
                .div,
                cross_cancellation,
                left,
                right,
                constraint,
                name,
            );
        }

        pub fn write(
            self: *const Self,
            io: *const std.Io,
        ) !void {
            try self.value.writeValue(io);

            const stdout: std.Io.File = .stdout();

            try stdout.writePositionalAll(io.*, " ", 0);
            try self.definition.writeUnits(io);
            try stdout.writePositionalAll(io.*, "\n", 0);
        }

        fn getAllocator() Allocator {
            return allocator orelse unreachable;
        }

        fn operate(
            comptime operation: Operation,
            left: *const Self,
            right: *const Self,
        ) !*Self {
            if (!left.definition.eql(right.definition.*))
                unreachable;

            const value: *N = switch (operation) {
                .add => try .add(left.value, right.value),
                .sub => try .sub(left.value, right.value),
                else => unreachable,
            };

            try left.definition.constraint.validate(value);

            return try init(value, left.definition);
        }

        fn scaleValue(
            comptime operation: Operation,
            left: *const Self,
            right: *const N,
        ) !Self {
            const value: *N = switch (operation) {
                .mul => try .mul(left.value, right),
                .div => try .div(left.value, right),
            };

            try left.definition.constraint.validate(value);

            return try init(value, left.definition);
        }

        fn combine(
            comptime operation: Operation,
            comptime cross_cancellation: bool,
            left: *const Self,
            right: *const Self,
            constraint: Constraint,
            name: ?[]const u8,
        ) !*Self {
            const definition: *UnitDefinition(N) = try .combine(
                operation,
                cross_cancellation,
                left.definition,
                right.definition,
                constraint,
                name,
            );

            const value: *N = switch (operation) {
                .mul => try .mul(left.value, right.value),
                .div => try .div(left.value, right.value),
                else => unreachable,
            };

            try definition.constraint.validate(value);

            return try init(value, definition);
        }
    };
}
