const Dynamics = @import("physics/dynamics.zig").Dynamics;
const ExtendedSI = @import("physics/extended_si.zig").ExtendedSI;
const SI = @import("physics/si.zig").SI;
const UnitDefinition = @import("unit/unit_definition.zig").UnitDefinition;

pub fn Physics(comptime Numeric: type) type {
    return struct {
        pub const NumericSI = SI(UnitDefinition(Numeric));
        pub const ExtendedNumericSI = ExtendedSI(UnitDefinition(Numeric));

        pub const NumericDynamics = Dynamics(Numeric);
    };
}
