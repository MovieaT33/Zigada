const std = @import("std");

const Quantity = @import("quantity.zig").Quantity;

const Allocator = std.mem.Allocator;

pub fn QuantityRegistry(comptime N: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        quantities: std.ArrayList(*Quantity(N)),

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .quantities = .empty,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.quantities.items) |quantity|
                quantity.deinit();

            self.quantities.deinit(self.allocator);
        }

        pub fn adopt(
            self: *Self,
            quantity: *Quantity(N),
        ) Allocator.Error!void {
            try self.quantities.append(self.allocator, quantity);
        }

        pub fn write(self: *const Self, io: *const std.Io) !void {
            for (self.quantities.items) |quantity|
                try quantity.write(io);
        }
    };
}
