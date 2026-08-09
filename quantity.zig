const std = @import("std");
const Dimension = @import("dimension.zig").Dimension;
const Dimensions = @import("dimensions.zig").Dimensions;

pub fn Quantity(comptime T: type) type {
    return struct {
        const Self = @This();

        const Operation = enum {
            mul,
            div,
        };

        value: T,
        dim: *Dimension,

        pub fn init(value: T, dimension: *Dimension) Self {
            return .{
                .value = value,
                .dim = dimension,
            };
        }

        pub fn show(
            self: *Self,
            buffer: []u8,
            io: *const std.Io,
        ) !void {
            const stdout = std.Io.File.stdout();

            const value = try std.fmt.bufPrint(
                buffer,
                "{} ",
                .{self.value},
            );

            try stdout.writePositionalAll(io.*, value, 0);

            try self.dim.*.showUnits(io);

            try stdout.writePositionalAll(io.*, "\n", 0);
        }

        pub fn add(a: *const Self, b: *const Self) Self {
            if (!a.dim.*.eql(&b.dim.*))
                unreachable;

            return .{
                .value = a.value + b.value,
                .dim = a.dim,
            };
        }

        pub fn sub(a: *const Self, b: *const Self) Self {
            if (!a.dim.*.eql(&b.dim.*))
                unreachable;

            return .{
                .value = a.value - b.value,
                .dim = a.dim,
            };
        }

        pub fn scale(a: *const Self, b: T) Self {
            return .{
                .value = a.value * b,
                .dim = a.dim,
            };
        }

        pub fn unscale(a: *const Self, b: T) Self {
            return .{
                .value = a.value / b,
                .dim = a.dim,
            };
        }

        // TODO: add cross-cancellation

        pub fn operate(
            a: *const Self,
            b: *const Self,
            comptime operation: Operation,
            new_name: ?[]const u8,
            dimensions: *Dimensions,
        ) !Self {
            var dim = try a.dim.clone(new_name);
            errdefer dim.deinit();

            switch (operation) {
                .mul => {
                    // Add b's numerator factors to numerator.
                    for (b.dim.numerator.items) |factor|
                        try dim.add(factor, .numerator);

                    // Add b's denominator factors to denominator.
                    for (b.dim.denominator.items) |factor|
                        try dim.add(factor, .denominator);
                },

                .div => {
                    // Move b's numerator factors to denominator.
                    for (b.dim.numerator.items) |factor|
                        try dim.add(factor, .denominator);

                    // Move b's denominator factors to numerator.
                    for (b.dim.denominator.items) |factor|
                        try dim.add(factor, .numerator);
                },
            }

            const calculated_value = switch (operation) {
                .mul => a.value * b.value,
                .div => a.value / b.value,
            };

            if (dimensions.find(dim)) |existing| {
                dim.deinit();

                return .{
                    .value = calculated_value,
                    .dim = existing,
                };
            }

            try dimensions.add(dim, true);

            return .{
                .value = calculated_value,
                .dim = dim,
            };
        }
    };
}
