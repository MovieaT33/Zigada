const std = @import("std");

const NumericWrapper = @import("numeric/numeric_wrapper.zig").NumericWrapper;
const Rational = @import("numeric/rational.zig").Rational;
const RationalRegistry = @import("numeric/rational_registry.zig").RationalRegistry;
const Quantity = @import("quantity/quantity.zig").Quantity;
const QuantityRegistry = @import("quantity/quantity_registry.zig").QuantityRegistry;
const SI = @import("unit/si.zig").SI;
const UnitDefinition = @import("unit/unit_definition.zig").UnitDefinition;
const UnitExpression = @import("unit/unit_expression.zig").UnitExpression;
const UnitRegistry = @import("unit/unit_registry.zig").UnitRegistry;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var gpa = std.heap.DebugAllocator(.{
        .safety = false,
    }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    // Registries
    var unit_registry: UnitRegistry = .init(allocator);
    defer {
        var stdout: std.Io.File = .stdout();
        stdout.writePositionalAll(io, "\n", 0) catch unreachable;

        unit_registry.write(&io) catch unreachable;
        unit_registry.deinit();
    }

    var quantity_registry = QuantityRegistry(Rational).init(allocator);
    defer quantity_registry.deinit();

    var rational_registry: RationalRegistry = .init(allocator);
    defer rational_registry.deinit();

    // Types
    UnitExpression.unit_registry = &unit_registry;

    const unit_definition = UnitDefinition(Rational);
    unit_definition.allocator = allocator;

    const Q = Quantity(Rational);
    Q.allocator = allocator;
    Q.quantity_registry = &quantity_registry;

    Rational.allocator = allocator;

    const zero: *Rational = try .init(0, 1);
    const non_negative: unit_definition.Constraint = .init(zero, null);

    const si: SI(Rational) = try .create(
        allocator,
        non_negative,
    );

    const velocity = try unit_definition.div(
        false,
        si.meter,
        si.second,
        non_negative,
        "velocity",
    );

    const m: *Rational = try .init(5, 1);
    const v1: *Rational = try .init(10, 1);
    const v2: *Rational = try .init(30, 1);
    const dt: *Rational = try .init(5, 1);
    const s: *Rational = try .init(2, 1);

    const mass: *Q = try .init(m, si.kilogram);
    const velocity_1: *Q = try .init(v1, velocity);
    const velocity_2: *Q = try .init(v2, velocity);
    const delta_time: *Q = try .init(dt, si.second);
    const side: *Q = try .init(s, si.meter);

    const delta_velocity: *Q = try .sub(
        velocity_2,
        velocity_1,
    );

    const acceleration: *Q = try .div(
        false,
        delta_velocity,
        delta_time,
        non_negative,
        "acceleration",
    );

    const force: *Q = try .mul(
        false,
        mass,
        acceleration,
        non_negative,
        "force",
    );
    try force.write(&io, undefined);

    const square: *Q = try .mul(
        false,
        side,
        side,
        non_negative,
        "square",
    );
    try square.write(&io, undefined);

    const pressure: *Q = try .div(
        true,
        force,
        square,
        non_negative,
        "pressure",
    );
    try pressure.write(&io, undefined);
}
