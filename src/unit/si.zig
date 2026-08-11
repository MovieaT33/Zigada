const std = @import("std");

const UnitDefinition = @import("unit_definition.zig").UnitDefinition;
const UnitRegistry = @import("unit_registry.zig").UnitRegistry;

const Allocator = std.mem.Allocator;

pub fn SI(comptime D: type) type {
    return struct {
        const Self = @This();

        second: *D,
        meter: *D,
        kilogram: *D,
        kelvin: *D,
        ampere: *D,
        mole: *D,
        candela: *D,

        pub fn create(
            non_negative: D.Constraint,
        ) Allocator.Error!Self {
            var second: *D = try .init(
                &.{.{ .unit = "s", .power = 1 }},
                &.{},
                non_negative,
                "si/time",
            );
            errdefer second.deinit();

            var meter: *D = try .init(
                &.{.{ .unit = "m", .power = 1 }},
                &.{},
                non_negative,
                "si/length",
            );
            errdefer meter.deinit();

            var kilogram: *D = try .init(
                &.{.{ .unit = "kg", .power = 1 }},
                &.{},
                non_negative,
                "si/mass",
            );
            errdefer kilogram.deinit();

            var kelvin: *D = try .init(
                &.{.{ .unit = "K", .power = 1 }},
                &.{},
                non_negative,
                "si/temperature",
            );
            errdefer kelvin.deinit();

            var ampere: *D = try .init(
                &.{.{ .unit = "A", .power = 1 }},
                &.{},
                non_negative,
                "si/electric current",
            );
            errdefer ampere.deinit();

            var mole: *D = try .init(
                &.{.{ .unit = "mol", .power = 1 }},
                &.{},
                non_negative,
                "si/amount of substance",
            );
            errdefer mole.deinit();

            var candela: *D = try .init(
                &.{.{ .unit = "cd", .power = 1 }},
                &.{},
                non_negative,
                "si/luminous intensity",
            );
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
