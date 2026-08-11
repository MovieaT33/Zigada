const std = @import("std");

const NumericWrapper = @import("numeric/numeric_wrapper.zig").NumericWrapper;
const Rational = @import("numeric/rational.zig").Rational;
const RationalRegistry = @import("numeric/rational_registry.zig").RationalRegistry;
const Quantity = @import("quantity.zig").Quantity;
const SI = @import("unit/si.zig").SI;
const UnitExpression = @import("unit/unit_expression.zig").UnitExpression;
const UnitRegistry = @import("unit/unit_registry.zig").UnitRegistry;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var gpa = std.heap.DebugAllocator(.{
        .safety = true,
    }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var unit_registry = UnitRegistry.init(allocator);
    defer {
        var stdout = std.Io.File.stdout();
        stdout.writePositionalAll(io, "\n", 0) catch unreachable;

        unit_registry.write(&io) catch unreachable;

        unit_registry.deinit();
    }

    var rational_registry = RationalRegistry.init(allocator);
    defer rational_registry.deinit();

    const si = try SI.create(allocator);
    try si.adopt(&unit_registry);

    const velocity =
        try UnitExpression.combine(si.meter, si.second, .div, "velocity", false);
    try unit_registry.adopt(velocity, true);

    Rational.rational_registry = &rational_registry;
    Rational.allocator = allocator;
    const Q = Quantity(Rational);
    Q.unit_registry = &unit_registry;
    Q.rational_registry = &rational_registry;

    const m = try Q.Type.init(5, 1);
    const v1 = try Q.Type.init(10, 1);
    const v2 = try Q.Type.init(30, 1);
    const dt = try Q.Type.init(5, 1);
    const s = try Q.Type.init(2, 1);

    const mass = Q.init(m, si.kilogram);
    const velocity_1 = Q.init(v1, velocity);
    const velocity_2 = Q.init(v2, velocity);
    const delta_time = Q.init(dt, si.second);
    const side = Q.init(s, si.meter);

    const delta_velocity =
        try Q.sub(velocity_2, velocity_1);

    const acceleration =
        try Q.div(delta_velocity, delta_time, "acceleration", false);

    const force =
        try Q.mul(mass, acceleration, "force", false);
    try force.write(&io, null);

    const square =
        try Q.mul(side, side, "square", false);
    try square.write(&io, null);

    const pressure =
        try Q.div(force, square, "pressure", true);
    try pressure.write(&io, null);
}
