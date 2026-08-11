const std = @import("std");

const UnitDefinition = @import("unit_definition.zig").UnitDefinition;
const UnitExpression = @import("unit_expression.zig").UnitExpression;
const UnitRegistry = @import("unit_registry.zig").UnitRegistry;

const Allocator = std.mem.Allocator;

pub fn SI(comptime N: type) type {
    return struct {
        const Self = @This();

        second: *UnitDefinition(N),
        meter: *UnitDefinition(N),
        kilogram: *UnitDefinition(N),
        kelvin: *UnitDefinition(N),
        ampere: *UnitDefinition(N),
        mole: *UnitDefinition(N),
        candela: *UnitDefinition(N),

        pub fn create(
            allocator: Allocator,
            non_negative: UnitDefinition(N).Constraint,
        ) Allocator.Error!Self {
            var second_expression: *UnitExpression = try .init(allocator, "time");
            errdefer second_expression.deinit();

            var meter_expression: *UnitExpression = try .init(allocator, "length");
            errdefer meter_expression.deinit();

            var kilogram_expression: *UnitExpression = try .init(allocator, "mass");
            errdefer kilogram_expression.deinit();

            var kelvin_expression: *UnitExpression = try .init(allocator, "temperature");
            errdefer kelvin_expression.deinit();

            var ampere_expression: *UnitExpression = try .init(allocator, "electric current");
            errdefer ampere_expression.deinit();

            var mole_expression: *UnitExpression = try .init(allocator, "amount of substance");
            errdefer mole_expression.deinit();

            var candela_expression: *UnitExpression = try .init(allocator, "luminous intensity");
            errdefer candela_expression.deinit();

            try second_expression.addFactor(.numerator, .{ .unit = "s", .power = 1 });
            try meter_expression.addFactor(.numerator, .{ .unit = "m", .power = 1 });
            try kilogram_expression.addFactor(.numerator, .{ .unit = "kg", .power = 1 });
            try kelvin_expression.addFactor(.numerator, .{ .unit = "K", .power = 1 });
            try ampere_expression.addFactor(.numerator, .{ .unit = "A", .power = 1 });
            try mole_expression.addFactor(.numerator, .{ .unit = "mol", .power = 1 });
            try candela_expression.addFactor(.numerator, .{ .unit = "cd", .power = 1 });

            const second: *UnitDefinition(N) = try .init(second_expression, non_negative);
            errdefer second.deinit();

            const meter: *UnitDefinition(N) = try .init(meter_expression, non_negative);
            errdefer meter.deinit();

            const kilogram: *UnitDefinition(N) = try .init(kilogram_expression, non_negative);
            errdefer kilogram.deinit();

            const kelvin: *UnitDefinition(N) = try .init(kelvin_expression, non_negative);
            errdefer kelvin.deinit();

            const ampere: *UnitDefinition(N) = try .init(ampere_expression, non_negative);
            errdefer ampere.deinit();

            const mole: *UnitDefinition(N) = try .init(mole_expression, non_negative);
            errdefer mole.deinit();

            const candela: *UnitDefinition(N) = try .init(candela_expression, non_negative);
            errdefer candela.deinit();

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
    };
}
