const std = @import("std");

const BigInt = @import("numeric/big_int.zig").BigInt;
const Rational = @import("numeric/rational.zig").Rational;
const RationalRegistry = @import("numeric/rational_registry.zig").RationalRegistry;
const Physics = @import("physics.zig").Physics;
const Quantity = @import("quantity/quantity.zig").Quantity;
const QuantityRegistry = @import("quantity/quantity_registry.zig").QuantityRegistry;
const UnitDefinition = @import("unit/unit_definition.zig").UnitDefinition;
const UnitRegistry = @import("unit/unit_registry.zig").UnitRegistry;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var gpa = std.heap.DebugAllocator(.{
        .safety = true,
    }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const RationalDefinition = UnitDefinition(Rational);
    const RationalQuantity = Quantity(Rational);

    var unit_registry: UnitRegistry(RationalDefinition) = .init(allocator);
    defer unit_registry.deinit();

    var quantity_registry: QuantityRegistry(RationalQuantity) = .init(allocator);
    defer quantity_registry.deinit();

    var rational_registry: RationalRegistry = .init(allocator);
    defer rational_registry.deinit();

    RationalDefinition.allocator = allocator;
    RationalDefinition.unit_registry = &unit_registry;

    RationalQuantity.allocator = allocator;
    RationalQuantity.quantity_registry = &quantity_registry;

    BigInt.allocator = allocator;

    Rational.allocator = allocator;
    Rational.rational_registry = &rational_registry;

    const non_negative: RationalDefinition.Constraint = .init(
        try Rational.init(0, 1),
        null,
    );

    const RationalPhysics = Physics(Rational);
    const RationalSI = RationalPhysics.NumericSI;
    const RationalDynamics = RationalPhysics.NumericDynamics;

    const si = try RationalSI.create(non_negative);

    RationalDynamics.non_negative = try non_negative.clone();

    const velocity: *RationalDefinition = try .div(
        false,
        si.meter,
        si.second,
        non_negative,
        "velocity",
    );

    const mass: *RationalQuantity = try .init(
        try Rational.init(5, 1),
        si.kilogram,
    );

    const velocity_1: *RationalQuantity = try .init(
        try Rational.init(1, 10),
        velocity,
    );

    const velocity_2: *RationalQuantity = try .init(
        try Rational.init(30, 1),
        velocity,
    );

    const time: *RationalQuantity = try .init(
        try Rational.init(10, 1),
        si.second,
    );

    const side: *RationalQuantity = try .init(
        try Rational.init(2, 1),
        si.meter,
    );

    const square: *RationalQuantity = try .mul(
        false,
        side,
        side,
        non_negative,
        "square",
    );

    const delta_velocity: *RationalQuantity = try .sub(
        velocity_2,
        velocity_1,
    );

    const acceleration: *RationalQuantity = try .div(
        false,
        delta_velocity,
        time,
        non_negative,
        "acceleration",
    );

    const force = try RationalDynamics.force(mass, acceleration);

    const pressure: *RationalQuantity = try .div(
        true,
        force,
        square,
        non_negative,
        "pressure",
    );

    _ = pressure;

    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    const writer_interface = &stdout_writer.interface;

    try unit_registry.write(writer_interface);
    try writer_interface.writeByte('\n');
    try quantity_registry.write(writer_interface);
}
