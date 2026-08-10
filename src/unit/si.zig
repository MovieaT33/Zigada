const std = @import("std");

const UnitExpression = @import("unit_expression.zig").UnitExpression;
const UnitRegistry = @import("unit_registry.zig").UnitRegistry;

const Allocator = std.mem.Allocator;

pub const SI = struct {
    const Self = @This();

    second: *UnitExpression,
    meter: *UnitExpression,
    kilogram: *UnitExpression,
    kelvin: *UnitExpression,
    ampere: *UnitExpression,
    mole: *UnitExpression,
    candela: *UnitExpression,

    pub fn create(allocator: Allocator) Allocator.Error!Self {
        var second = try UnitExpression.init("time", allocator);
        errdefer second.deinit();

        var meter = try UnitExpression.init("length", allocator);
        errdefer meter.deinit();

        var kilogram = try UnitExpression.init("mass", allocator);
        errdefer kilogram.deinit();

        var kelvin = try UnitExpression.init("temperature", allocator);
        errdefer kelvin.deinit();

        var ampere = try UnitExpression.init("electric current", allocator);
        errdefer ampere.deinit();

        var mole = try UnitExpression.init("amount of substance", allocator);
        errdefer mole.deinit();

        var candela = try UnitExpression.init("luminous intensity", allocator);
        errdefer candela.deinit();

        try second.addFactor(.{ .unit = "s", .power = 1 }, .numerator);
        try meter.addFactor(.{ .unit = "m", .power = 1 }, .numerator);
        try kilogram.addFactor(.{ .unit = "kg", .power = 1 }, .numerator);
        try kelvin.addFactor(.{ .unit = "K", .power = 1 }, .numerator);
        try ampere.addFactor(.{ .unit = "A", .power = 1 }, .numerator);
        try mole.addFactor(.{ .unit = "mol", .power = 1 }, .numerator);
        try candela.addFactor(.{ .unit = "cd", .power = 1 }, .numerator);

        return .{
            .second = second,
            .meter = meter,
            .kilogram = kilogram,
            .kelvin = kelvin,
            .ampere = ampere,
            .mole = mole,
            .candela = candela,
        };
    }

    pub fn adopt(self: *const Self, registry: *UnitRegistry) Allocator.Error!void {
        try registry.adopt(self.second, true);
        try registry.adopt(self.meter, true);
        try registry.adopt(self.kilogram, true);
        try registry.adopt(self.kelvin, true);
        try registry.adopt(self.ampere, true);
        try registry.adopt(self.mole, true);
        try registry.adopt(self.candela, true);
    }
};
