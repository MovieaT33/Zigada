const Dynamics = @import("physics/dynamics.zig").Dynamics;
const ExtendedSI = @import("physics/extended_si.zig").ExtendedSI;
const SI = @import("physics/si.zig").SI;
const UnitDefinition = @import("unit/unit_definition.zig").UnitDefinition;

pub fn Physics(comptime Numeric: type) type {
    const NumericDefinition = UnitDefinition(Numeric);

    return struct {
        pub const NumericSI = SI(NumericDefinition);
        pub const ExtendedNumericSI = ExtendedSI(NumericDefinition);

        pub const NumericDynamics = Dynamics(Numeric);
    };
}
