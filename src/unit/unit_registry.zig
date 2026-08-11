const std = @import("std");

const UnitDefinition = @import("unit_definition.zig").UnitDefinition;

const Allocator = std.mem.Allocator;

pub fn UnitRegistry(comptime N: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        definitions: std.ArrayList(*UnitDefinition(N)),

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .definitions = .empty,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.definitions.items) |definition|
                definition.deinit();

            self.definitions.deinit(self.allocator);
        }

        pub fn find(
            self: *const Self,
            definition: UnitDefinition(N),
        ) ?*UnitDefinition(N) {
            for (self.definitions.items) |existing| {
                if (existing.eql(definition))
                    return existing;
            }

            return null;
        }

        pub fn adopt(
            self: *Self,
            definition: *UnitDefinition(N),
        ) Allocator.Error!void {
            try self.definitions.append(self.allocator, definition);
        }

        pub fn write(
            self: *const Self,
            io: *const std.Io,
        ) !void {
            for (self.definitions.items) |definition|
                try definition.write(io);
        }
    };
}
