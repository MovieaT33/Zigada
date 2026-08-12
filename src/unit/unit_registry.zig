const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn UnitRegistry(comptime Definition: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        definitions: std.ArrayList(*Definition),

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

        pub fn adopt(
            self: *Self,
            definition: *Definition,
        ) Allocator.Error!void {
            try self.definitions.append(self.allocator, definition);
        }

        pub fn write(
            self: *const Self,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            for (self.definitions.items) |definition| {
                try definition.write(writer);
                try writer.writeByte('\n');
            }
        }
    };
}
