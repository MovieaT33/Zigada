const std = @import("std");

const config = @import("config.zig");

const Allocator = std.mem.Allocator;

pub const UnitFactor = struct {
    const Self = @This();

    unit: []const u8,
    power: u32,

    pub fn appendPower(
        self: *const Self,
        text: *std.ArrayList(u8),
        allocator: Allocator,
    ) !void {
        var print_buffer: [config.print_buffer_size]u8 = undefined;

        const power_text = try std.fmt.bufPrint(
            &print_buffer,
            "^{}",
            .{self.power},
        );

        try text.appendSlice(allocator, power_text);
    }

    pub fn appendText(
        self: *const Self,
        text: *std.ArrayList(u8),
        allocator: Allocator,
    ) !void {
        try text.appendSlice(allocator, self.unit);

        if (self.power != 1)
            try self.appendPower(text, allocator);
    }

    pub fn appendFactors(
        text: *std.ArrayList(u8),
        factors: []const Self,
        allocator: Allocator,
    ) !void {
        for (factors, 0..) |factor, index| {
            if (index != 0)
                try text.append(allocator, '*');

            try factor.appendText(text, allocator);
        }
    }
};
