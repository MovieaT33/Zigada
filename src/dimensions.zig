const std = @import("std");

const Dimension = @import("dimension.zig").Dimension;

const Allocator = std.mem.Allocator;

pub const Dimensions = struct {
    const Self = @This();

    list: std.ArrayList(*Dimension),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return .{
            .list = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.list.items) |dimension|
            dimension.deinit();

        self.list.deinit(self.allocator);
    }

    pub fn append(self: *Self, dimension: *Dimension) Allocator.Error!void {
        try self.list.append(self.allocator, dimension);
    }

    pub fn appendUnique(
        self: *Self,
        dimension: *Dimension,
    ) Allocator.Error!void {
        if (self.exists(dimension.*))
            return;

        try self.list.append(self.allocator, dimension);
    }

    pub fn write(self: *const Self, io: *const std.Io) !void {
        for (self.list.items) |dimension|
            try dimension.write(io);
    }

    pub fn exists(self: *const Self, dimension: Dimension) bool {
        for (self.list.items) |existing| {
            if (existing.equal(dimension))
                return true;
        }

        return false;
    }

    pub fn find(self: *const Self, dimension: Dimension) ?*Dimension {
        for (self.list.items) |existing| {
            if (existing.equal(dimension))
                return existing;
        }

        return null;
    }
};
