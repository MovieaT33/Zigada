const std = @import("std");

const SI = @import("si.zig").SI;

pub fn ExtendedSI(comptime Definition: type) type {
    return struct {
        const Self = @This();

        // Dynamics
        velocity: *Definition,
        acceleration: *Definition,
        force: *Definition,
        area: *Definition,
        pressure: *Definition,
        joule: *Definition,
        power: *Definition,
        volume: *Definition,
        density: *Definition,

        // Unused
        frequency: *Definition,
        momentum: *Definition,

        pub fn create(
            non_negative: Definition.Constraint,
            si: SI(Definition),
        ) std.mem.Allocator.Error!Self {
            const name_prefix = "extended si/";

            const velocity: *Definition = try .div(
                false,
                si.meter,
                si.second,
                non_negative,
                name_prefix ++ "velocity",
                null,
            );

            const acceleration: *Definition = try .div(
                false,
                velocity,
                si.second,
                non_negative,
                name_prefix ++ "acceleration",
                null,
            );

            const force: *Definition = try .mul(
                false,
                si.kilogram,
                acceleration,
                non_negative,
                name_prefix ++ "force",
                null,
            );

            const area: *Definition = try .mul(
                false,
                si.meter,
                si.meter,
                non_negative,
                name_prefix ++ "area",
                null,
            );

            const pressure: *Definition = try .div(
                true,
                force,
                area,
                non_negative,
                name_prefix ++ "pressure",
                null,
            );

            const joule: *Definition = try .mul(
                false,
                force,
                si.meter,
                non_negative,
                name_prefix ++ "joule",
                null,
            );

            const power: *Definition = try .div(
                true,
                joule,
                si.second,
                non_negative,
                name_prefix ++ "power",
                null,
            );

            const volume: *Definition = try .mul(
                false,
                area,
                si.meter,
                non_negative,
                name_prefix ++ "volume",
                null,
            );

            const density: *Definition = try .div(
                true,
                si.kilogram,
                volume,
                non_negative,
                name_prefix ++ "density",
                null,
            );

            return .{
                .velocity = velocity,
                .acceleration = acceleration,
                .force = force,
                .area = area,
                .pressure = pressure,
                .joule = joule,
                .power = power,
                .volume = volume,
                .density = density,

                .frequency = undefined,
                .momentum = undefined,
            };
        }
    };
}
