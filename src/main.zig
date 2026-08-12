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
    const ExtendedRationalSI = RationalPhysics.ExtendedNumericSI;
    const RationalDynamics = RationalPhysics.NumericDynamics;

    const si =
        try RationalSI.create(non_negative);
    const extended_si =
        try ExtendedRationalSI.create(non_negative, si);

    RationalDynamics.si = si;
    RationalDynamics.extended_si = extended_si;
    RationalDynamics.non_negative = try non_negative.clone();

    const mass: *RationalQuantity = try .init(
        try Rational.init(5, 1),
        si.kilogram,
        "m",
    );

    const acceleration: *RationalQuantity = try .init(
        try Rational.init(981, 100),
        extended_si.acceleration,
        "a",
    );

    const force = try RationalDynamics.calculateForce(
        mass,
        acceleration,
        "F",
    );

    const area: *RationalQuantity = try .init(
        try Rational.init(4, 1),
        extended_si.area,
        "A",
    );

    const pressure: *RationalQuantity = try RationalDynamics.calculatePressure(
        force,
        area,
        "p",
    );

    _ = pressure;

    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    const writer_interface = &stdout_writer.interface;

    try unit_registry.write(writer_interface);
    try writer_interface.writeByte('\n');
    try quantity_registry.write(writer_interface);
}
