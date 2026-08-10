const std = @import("std");

const config = @import("config.zig");
const NumericWrapper = @import("numeric_wrapper.zig").NumericWrapper;
const Quantity = @import("quantity.zig").Quantity;
const SI = @import("si.zig").SI;
const UnitExpression = @import("unit_expression.zig").UnitExpression;
const UnitRegistry = @import("unit_registry.zig").UnitRegistry;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // Initialize GPA
    var gpa = std.heap.DebugAllocator(.{
        .safety = true,
    }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    // Initialize unit registry
    var registry = UnitRegistry.init(allocator);
    defer {
        var stdout = std.Io.File.stdout();
        stdout.writePositionalAll(io, "\n", 0) catch unreachable;

        registry.write(&io) catch unreachable;

        registry.deinit();
    }

    // Create SI
    const si = try SI.create(allocator);

    // Initialize complex unit expressions
    const velocity = try UnitExpression.combine(
        si.meter,
        si.second,
        .div,
        "velocity",
        false,
    );

    // Adopt expressions to registry
    try si.adopt(&registry);
    try registry.adopt(velocity, true);

    // Create a quantity type
    const Q32 = Quantity(NumericWrapper(f32));

    // Example:
    var print_buffer: [config.print_buffer_size]u8 = undefined;

    const mass = Q32.init(5, si.kilogram);
    const velocity_1 = Q32.init(10, velocity);
    const velocity_2 = Q32.init(30, velocity);
    const delta_time = Q32.init(5, si.second);
    const side = Q32.init(2, si.meter);

    const delta_velocity = try Q32.sub(velocity_2, velocity_1);

    const acceleration = try Q32.div(
        delta_velocity,
        delta_time,
        "acceleration",
        &registry,
        false,
    );

    var force = try Q32.mul(
        mass,
        acceleration,
        "force",
        &registry,
        false,
    );
    try force.write(&print_buffer, &io);

    var square = try Q32.mul(
        side,
        side,
        "square",
        &registry,
        false,
    );
    try square.write(&print_buffer, &io);

    var pressure = try Q32.div(
        force,
        square,
        "pressure",
        &registry,
        true,
    );
    try pressure.write(&print_buffer, &io);
}
