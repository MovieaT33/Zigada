// Checked style

const std = @import("std");

const Allocator = std.mem.Allocator;

pub const UnitFactor = struct {
    const Self = @This();

    unit: []const u8,
    power: u8,

    pub fn appendPower(
        self: *const Self,
        allocator: Allocator,
        text: *std.ArrayList(u8),
    ) !void {
        var print_buffer: [4]u8 = undefined; // "^255"

        const power_text = try std.fmt.bufPrint(
            &print_buffer,
            "^{}",
            .{self.power},
        );

        try text.appendSlice(allocator, power_text);
    }

    pub fn appendText(
        self: *const Self,
        allocator: Allocator,
        text: *std.ArrayList(u8),
    ) !void {
        try text.appendSlice(allocator, self.unit);

        if (self.power != 1)
            try self.appendPower(allocator, text);
    }

    pub fn appendFactors(
        allocator: Allocator,
        text: *std.ArrayList(u8),
        factors: []const Self,
    ) !void {
        for (factors, 0..) |factor, index| {
            if (index != 0)
                try text.append(allocator, '*');

            try factor.appendText(allocator, text);
        }
    }
};
