const std = @import("std");
const Allocator = std.mem.Allocator;

const Dimension = @import("dimension.zig").Dimension;

pub const Dimensions = struct {
    const Self = @This();

    list: std.ArrayList(*Dimension),
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) Self {
        return .{
            .list = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.allocator.*;

        for (self.list.items) |dimension|
            dimension.deinit();

        self.list.deinit(allocator);
    }

    pub fn exists(self: *const Self, dimension: Dimension) bool {
        for (self.list.items) |existing| {
            if (existing.eql(dimension))
                return true;
        }

        return false;
    }

    pub fn find(self: *const Self, dimension: Dimension) ?*Dimension {
        for (self.list.items) |existing| {
            if (existing.eql(dimension))
                return existing;
        }

        return null;
    }

    pub fn add(
        self: *Self,
        dimension: *Dimension,
        ignore_duplicate: bool,
    ) Allocator.Error!void {
        if (!ignore_duplicate) {
            if (self.exists(dimension.*))
                return;
        }

        try self.list.append(self.allocator.*, dimension);
    }

    pub fn show(self: *const Self, io: *const std.Io) !void {
        for (self.list.items) |dimension|
            try dimension.*.show(io);
    }
};
