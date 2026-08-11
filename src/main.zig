const std = @import("std");

const Rational = @import("numeric/rational.zig").Rational;
const RationalRegistry = @import("numeric/rational_registry.zig").RationalRegistry;
const Quantity = @import("quantity/quantity.zig").Quantity;
const QuantityRegistry = @import("quantity/quantity_registry.zig").QuantityRegistry;
const SI = @import("unit/si.zig").SI;
const UnitDefinition = @import("unit/unit_definition.zig").UnitDefinition;
const UnitRegistry = @import("unit/unit_registry.zig").UnitRegistry;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var gpa = std.heap.DebugAllocator(.{
        .safety = true,
    }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var unit_registry = UnitRegistry(Rational).init(allocator);
    defer unit_registry.deinit();

    var rational_registry = RationalRegistry.init(allocator);
    defer rational_registry.deinit();

    var quantity_registry = QuantityRegistry(Rational).init(allocator);
    defer quantity_registry.deinit();

    const RationalDefinition = UnitDefinition(Rational);
    RationalDefinition.allocator = allocator;
    RationalDefinition.unit_registry = &unit_registry;

    Rational.allocator = allocator;
    Rational.rational_registry = &rational_registry;

    const zero: *Rational = try .init(0, 1);

    const RationalQuantity = Quantity(Rational);
    RationalQuantity.allocator = allocator;
    RationalQuantity.quantity_registry = &quantity_registry;

    const non_negative: RationalDefinition.Constraint = .init(
        zero,
        null,
    );

    const si = try SI(RationalDefinition).create(non_negative);

    const velocity = try RationalDefinition.div(
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
        try Rational.init(10, 1),
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

    const force: *RationalQuantity = try .mul(
        false,
        mass,
        acceleration,
        non_negative,
        "force",
    );

    const pressure: *RationalQuantity = try .div(
        true,
        force,
        square,
        non_negative,
        "pressure",
    );

    _ = pressure;

    try quantity_registry.write(&io);
    try unit_registry.write(&io);
}
