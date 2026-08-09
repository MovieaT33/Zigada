const std = @import("std");
const Dimension = @import("dimension.zig").Dimension;

pub const Error = error{
    DimensionMismatch,
};

pub fn Quantity(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        dim: Dimension,

        pub fn init(value: T, dimension: Dimension) Self {
            return .{
                .value = value,
                .dim = dimension,
            };
        }

        pub fn show(
            self: *Self,
            label: []const u8,
            buffer: []u8,
            io: *const std.Io,
        ) !void {
            const stdout = std.Io.File.stdout();

            try stdout.writePositionalAll(
                io.*,
                label,
                0,
            );

            try stdout.writePositionalAll(
                io.*,
                ": ",
                0,
            );

            const value = try std.fmt.bufPrint(
                buffer,
                "{} ",
                .{self.value},
            );

            try stdout.writePositionalAll(
                io.*,
                value,
                0,
            );

            try self.dim.show(io);
        }

        pub fn add(a: *const Self, b: *const Self) Error!Self {
            if (!a.dim.eql(&b.dim))
                return error.DimensionMismatch;

            return .{
                .value = a.value + b.value,
                .dim = a.dim,
            };
        }

        pub fn sub(a: *const Self, b: *const Self) Error!Self {
            if (!a.dim.eql(&b.dim))
                return error.DimensionMismatch;

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

        pub fn mul(a: *const Self, b: *const Self) !Self {
            var dim = try a.dim.clone();
            errdefer dim.deinit();

            for (b.dim.numerator.items) |factor|
                try dim.add(factor, .numerator);

            for (b.dim.denominator.items) |factor|
                try dim.add(factor, .denominator);

            return .{
                .value = a.value * b.value,
                .dim = dim,
            };
        }

        pub fn div(a: *const Self, b: *const Self) !Self {
            var dimension = try a.dim.clone();
            errdefer dimension.deinit();

            for (b.dim.numerator.items) |factor|
                try dimension.add(factor, .denominator);

            for (b.dim.denominator.items) |factor|
                try dimension.add(factor, .numerator);

            return .{
                .value = a.value / b.value,
                .dim = dimension,
            };
        }
    };
}
