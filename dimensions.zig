const std = @import("std");
const Allocator = std.mem.Allocator;

const Dimension = @import("dimension.zig").Dimension;

pub const Dimensions = struct {
    const Self = @This();

    dims: std.ArrayList(*Dimension),
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) Self {
        return .{
            .dims = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.allocator.*;

        for (self.dims.items) |dimension|
            dimension.*.deinit();

        self.dims.deinit(allocator);
    }

    pub fn addDimension(
        self: *Self,
        dimension: *Dimension,
        ignore_duplicate: bool,
    ) Allocator.Error!*Dimension {
        if (!ignore_duplicate) {
            for (self.dims.items) |existing| {
                if (existing.eql(dimension))
                    return existing;
            }
        }

        try self.dims.append(self.allocator.*, dimension);

        return self.dims.items[self.dims.items.len - 1];
    }

    pub fn show(self: *const Self, io: *const std.Io) !void {
        for (self.dims.items) |dimension|
            try dimension.*.show(io);
    }
};
