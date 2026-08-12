const Quantity = @import("../quantity/quantity.zig").Quantity;
const UnitDefinition = @import("../unit/unit_definition.zig").UnitDefinition;
const ExtendedSI = @import("extended_si.zig").ExtendedSI;
const SI = @import("si.zig").SI;

pub fn Dynamics(comptime Numeric: type) type {
    const NumericDefinition = UnitDefinition(Numeric);
    const NumericSI = SI(NumericDefinition);
    const ExtendedNumericSI = ExtendedSI(NumericDefinition);
    const Constraint = NumericDefinition.Constraint;
    const NumericQuantity = Quantity(Numeric);

    return struct {
        pub var si: ?NumericSI = null;
        pub var extended_si: ?ExtendedNumericSI = null;
        pub var non_negative: ?Constraint = null;

        pub fn calculateForce(
            mass: *const NumericQuantity,
            acceleration: *const NumericQuantity,
            label: ?[]const u8,
        ) !*NumericQuantity {
            const _si = getSI();
            const _extended_si = getExtendedSI();

            try mass.assertSameDefinition(_si.kilogram);
            try acceleration.assertSameDefinition(_extended_si.acceleration);

            return try NumericQuantity.mul(
                false,
                mass,
                acceleration,
                getConstraint(),
                null,
                label,
                _extended_si.force,
            );
        }

        pub fn calculatePressure(
            force: *const NumericQuantity,
            area: *const NumericQuantity,
            label: ?[]const u8,
        ) !*NumericQuantity {
            const _extended_si = getExtendedSI();

            try force.assertSameDefinition(_extended_si.force);
            try area.assertSameDefinition(_extended_si.area);

            return try NumericQuantity.div(
                true,
                force,
                area,
                getConstraint(),
                null,
                label,
                null,
            );
        }

        fn getSI() NumericSI {
            return si orelse unreachable; // SI must be initialized
        }

        fn getExtendedSI() ExtendedNumericSI {
            return extended_si orelse unreachable; // Extended SI must be initialized
        }

        fn getConstraint() Constraint {
            return non_negative orelse unreachable; // Constraint must be initialized
        }
    };
}
