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

        // F = m * a
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

        // F = P * S
        pub fn calculateForceFromPressure(
            pressure: *const NumericQuantity,
            area: *const NumericQuantity,
            label: ?[]const u8,
        ) !*NumericQuantity {
            const _extended_si = getExtendedSI();

            try pressure.assertSameDefinition(_extended_si.pressure);
            try area.assertSameDefinition(_extended_si.area);

            return try NumericQuantity.mul(
                true,
                pressure,
                area,
                getConstraint(),
                null,
                label,
                _extended_si.force,
            );
        }

        // P = F / S
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
                _extended_si.pressure,
            );
        }

        // A = F * d
        pub fn calculateWork(
            force: *const NumericQuantity,
            distance: *const NumericQuantity,
            label: ?[]const u8,
        ) !*NumericQuantity {
            const _si = getSI();
            const _extended_si = getExtendedSI();

            try force.assertSameDefinition(_extended_si.force);
            try distance.assertSameDefinition(_si.meter);

            return try NumericQuantity.mul(
                false,
                force,
                distance,
                getConstraint(),
                null,
                label,
                _extended_si.joule,
            );
        }

        // P = A / t
        pub fn calculatePower(
            joule: *const NumericQuantity,
            time: *const NumericQuantity,
            label: ?[]const u8,
        ) !*NumericQuantity {
            const _si = getSI();
            const _extended_si = getExtendedSI();

            try joule.assertSameDefinition(_extended_si.joule);
            try time.assertSameDefinition(_si.second);

            return try NumericQuantity.div(
                true,
                joule,
                time,
                getConstraint(),
                null,
                label,
                _extended_si.power,
            );
        }

        // m = V * p
        pub fn calculateMassFromDensity(
            volume: *const NumericQuantity,
            density: *const NumericQuantity,
            label: ?[]const u8,
        ) !*NumericQuantity {
            const _si = getSI();
            const _extended_si = getExtendedSI();

            try volume.assertSameDefinition(_extended_si.volume);
            try density.assertSameDefinition(_extended_si.density);

            return try NumericQuantity.mul(
                false,
                density,
                volume,
                getConstraint(),
                null,
                label,
                _si.kilogram,
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
