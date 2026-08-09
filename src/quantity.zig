const std = @import("std");

const Dimension = @import("dimension.zig").Dimension;
const Dimensions = @import("dimensions.zig").Dimensions;

pub fn Quantity(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        dim: *Dimension,

        pub fn init(value: T, dimension: *Dimension) Self {
            return .{
                .value = value,
                .dim = dimension,
            };
        }

        pub fn writeValue(
            self: *const Self,
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
        }

        pub fn write(
            self: *const Self,
            buffer: []u8,
            io: *const std.Io,
        ) !void {
            const stdout = std.Io.File.stdout();

            try self.writeValue(buffer, io);

            try self.dim.writeUnits(io);

            try stdout.writePositionalAll(io.*, "\n", 0);
        }

        pub fn add(a: Self, b: Self) Self {
            if (!a.dim.eql(b.dim.*))
                unreachable;

            return .{
                .value = a.value + b.value,
                .dim = a.dim,
            };
        }

        pub fn sub(a: Self, b: Self) Self {
            if (!a.dim.equal(b.dim.*))
                unreachable;

            return .{
                .value = a.value - b.value,
                .dim = a.dim,
            };
        }

        pub fn scale(a: Self, b: T) Self {
            return .{
                .value = a.value * b,
                .dim = a.dim,
            };
        }

        pub fn unscale(a: Self, b: T) Self {
            return .{
                .value = a.value / b,
                .dim = a.dim,
            };
        }

        pub fn combine(
            a: Self,
            b: Self,
            comptime operation: Dimension.Operation,
            name: ?[]const u8,
            dimensions: *Dimensions,
            comptime cross_cancellation: bool,
        ) !Self {
            const dim = try Dimension.combine(
                a.dim,
                b.dim,
                operation,
                name,
                cross_cancellation,
            );

            const value = switch (operation) {
                .mul => a.value * b.value,
                .div => a.value / b.value,
            };

            if (dimensions.find(dim.*)) |existing| {
                dim.deinit();

                return .{
                    .value = value,
                    .dim = existing,
                };
            }

            try dimensions.append(dim);

            return .{
                .value = value,
                .dim = dim,
            };
        }
    };
}
