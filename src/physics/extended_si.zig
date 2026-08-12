const std = @import("std");

const SI = @import("si.zig").SI;

const Allocator = std.mem.Allocator;

pub fn ExtendedSI(comptime Definition: type) type {
    return struct {
        const Self = @This();

        // Dynamics
        velocity: *Definition,
        acceleration: *Definition,
        force: *Definition,
        area: *Definition,
        pressure: *Definition,

        // Currently unused:
        density: *Definition,
        energy: *Definition,
        frequency: *Definition,
        momentum: *Definition,
        volume: *Definition,
        work: *Definition,

        pub fn create(
            non_negative: Definition.Constraint,
            si: SI(Definition),
        ) Allocator.Error!Self {
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

            return .{
                .velocity = velocity,
                .acceleration = acceleration,
                .force = force,
                .area = area,
                .pressure = pressure,

                .density = undefined,
                .energy = undefined,
                .frequency = undefined,
                .momentum = undefined,
                .volume = undefined,
                .work = undefined,
            };
        }
    };
}
