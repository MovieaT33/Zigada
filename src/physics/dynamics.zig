const Quantity = @import("../quantity/quantity.zig").Quantity;
const UnitDefinition = @import("../unit/unit_definition.zig").UnitDefinition;

pub fn Dynamics(comptime Numeric: type) type {
    const Constraint = UnitDefinition(Numeric).Constraint;
    const NumericQuantity = Quantity(Numeric);

    return struct {
        pub var non_negative: ?Constraint = null;

        pub fn force(
            mass: *const NumericQuantity,
            acceleration: *const NumericQuantity,
        ) !*NumericQuantity {
            return try NumericQuantity.mul(
                false,
                mass,
                acceleration,
                getConstraint(),
                "force",
            );
        }

        fn getConstraint() Constraint {
            return non_negative orelse unreachable;
        }
    };
}
