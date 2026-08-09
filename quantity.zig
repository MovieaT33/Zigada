const std = @import("std");
const Dimension = @import("dimension.zig").Dimension;

pub const Error = error{
    DimensionMismatch,
};

pub fn Quantity(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        dimension: Dimension, // TODO: too long

        pub fn init(value: T, dimension: Dimension) Self {
            return .{
                .value = value,
                .dimension = dimension,
            };
        }

        pub fn show(self: *Self, io: *const std.Io) !void { // TODO: add `label`
            const stdout = std.Io.File.stdout();

            var buffer: [32]u8 = undefined;
            const value = try std.fmt.bufPrint(
                &buffer,
                "{} ",
                .{self.value},
            );

            try stdout.writePositionalAll(
                io.*,
                value,
                0,
            );

            try self.dimension.show(io);
        }

        pub fn add(a: *const Self, b: *const Self) Error!Self {
            if (!a.dimension.eql(&b.dimension))
                return error.DimensionMismatch;

            return .{
                .value = a.value + b.value,
                .dimension = a.dimension,
            };
        }

        pub fn sub(a: *const Self, b: *const Self) Error!Self {
            if (!a.dimension.eql(&b.dimension))
                return error.DimensionMismatch;

            return .{
                .value = a.value - b.value,
                .dimension = a.dimension,
            };
        }

        pub fn scale(a: *const Self, b: T) Self {
            return .{
                .value = a.value * b,
                .dimension = a.dimension,
            };
        }

        pub fn unscale(a: *const Self, b: T) Self {
            return .{
                .value = a.value / b,
                .dimension = a.dimension,
            };
        }

        pub fn mul(a: *const Self, b: *const Self) !Self {
            var dimension = try a.dimension.clone();
            errdefer dimension.deinit();

            for (b.dimension.numerator.items) |factor|
                try dimension.add(factor, .numerator);

            for (b.dimension.denominator.items) |factor|
                try dimension.add(factor, .denominator);

            return .{
                .value = a.value * b.value,
                .dimension = dimension,
            };
        }

        pub fn div(a: *const Self, b: *const Self) !Self {
            var dimension = try a.dimension.clone();
            errdefer dimension.deinit();

            for (b.dimension.numerator.items) |factor|
                try dimension.add(factor, .denominator);

            for (b.dimension.denominator.items) |factor|
                try dimension.add(factor, .numerator);

            return .{
                .value = a.value / b.value,
                .dimension = dimension,
            };
        }
    };
}
