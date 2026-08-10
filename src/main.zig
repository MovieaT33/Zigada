const std = @import("std");

const config = @import("config.zig");
const NumericWrapper = @import("numeric/numeric_wrapper.zig").NumericWrapper;
const Rational = @import("numeric/rational.zig").Rational;
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

    const si = try SI.create(allocator);
    try si.adopt(&unit_registry);

    const velocity = try UnitExpression.combine(
        si.meter,
        si.second,
        .div,
        "velocity",
        false,
    );
    try unit_registry.adopt(velocity, true);

    // const Q = Quantity(NumericWrapper(f32));
    const Q = Quantity(Rational);
    Q.registry = &unit_registry;

    // const mass = Q.init(Q.Type.init(5), si.kilogram);
    // const velocity_1 = Q.init(Q.Type.init(10), velocity);
    // const velocity_2 = Q.init(Q.Type.init(30), velocity);
    // const delta_time = Q.init(Q.Type.init(5), si.second);
    // const side = Q.init(Q.Type.init(2), si.meter);

    var m = try Q.Type.init(5, 1, allocator);
    defer m.deinit();
    var v1 = try Q.Type.init(10, 1, allocator);
    defer v1.deinit();
    var v2 = try Q.Type.init(30, 1, allocator);
    defer v2.deinit();
    var dt = try Q.Type.init(5, 1, allocator);
    defer dt.deinit();
    var s = try Q.Type.init(2, 1, allocator);
    defer s.deinit();

    const mass = Q.init(m, si.kilogram);
    const velocity_1 = Q.init(v1, velocity);
    const velocity_2 = Q.init(v2, velocity);
    const delta_time = Q.init(dt, si.second);
    const side = Q.init(s, si.meter);

    // var print_buffer: [config.print_buffer_size]u8 = undefined;

    var delta_velocity = try Q.sub(velocity_2, velocity_1);
    defer delta_velocity.deinit();

    var acceleration = try Q.div(
        delta_velocity,
        delta_time,
        "acceleration",
        false,
    );
    defer acceleration.deinit();

    var force = try Q.mul(
        mass,
        acceleration,
        "force",
        false,
    );
    defer force.deinit();
    // try force.write(&print_buffer, &io);
    try force.write(&io, null);

    var square = try Q.mul(
        side,
        side,
        "square",
        false,
    );
    defer square.deinit();
    // try square.write(&print_buffer, &io);
    try square.write(&io, null);

    var pressure = try Q.div(
        force,
        square,
        "pressure",
        true,
    );
    defer pressure.deinit();
    // try pressure.write(&print_buffer, &io);
    try pressure.write(&io, null);
}
