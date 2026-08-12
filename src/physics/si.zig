const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn SI(comptime Definition: type) type {
    return struct {
        const Self = @This();

        ampere: *Definition,
        candela: *Definition,
        kelvin: *Definition,
        kilogram: *Definition,
        meter: *Definition,
        mole: *Definition,
        second: *Definition,

        pub fn create(
            non_negative: Definition.Constraint,
        ) Allocator.Error!Self {
            var self: Self = undefined;

            const units = .{
                .ampere = .{ "A", "electric current" },
                .candela = .{ "cd", "luminous intensity" },
                .kelvin = .{ "K", "temperature" },
                .kilogram = .{ "kg", "mass" },
                .meter = .{ "m", "length" },
                .mole = .{ "mol", "amount of substance" },
                .second = .{ "s", "time" },
            };

            inline for (std.meta.fields(Self), 0..) |field, i| {
                const info = @field(units, field.name);

                @field(self, field.name) = try Definition.init(
                    &.{.{ .unit = info[0], .power = 1 }},
                    &.{},
                    non_negative,
                    "si/" ++ info[1],
                );

                errdefer {
                    inline for (std.meta.fields(Self)[0..i]) |created| {
                        @field(self, created.name).deinit();
                    }
                }
            }

            return self;
        }
    };
}
