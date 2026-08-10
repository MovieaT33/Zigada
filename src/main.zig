const std = @import("std");

const config = @import("config.zig");
const Quantity = @import("quantity.zig").Quantity;
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

    // Initialize base unit expressions
    var kilograms = try UnitExpression.init("mass", allocator);
    var meters = try UnitExpression.init("size", allocator);
    var seconds = try UnitExpression.init("time", allocator);

    // Add unit factors to expressions
    try kilograms.addFactor(
        .{ .unit = "kg", .power = 1 },
        .numerator,
    );

    try meters.addFactor(
        .{ .unit = "m", .power = 1 },
        .numerator,
    );

    try seconds.addFactor(
        .{ .unit = "s", .power = 1 },
        .numerator,
    );

    // Initialize complex unit expressions
    const velocity = try UnitExpression.combine(
        meters,
        seconds,
        .div,
        "velocity",
        false,
    );

    // Adopt expressions to list
    try registry.adopt(kilograms);
    try registry.adopt(meters);
    try registry.adopt(seconds);
    try registry.adopt(velocity);

    // Create a quantity type
    const Q32 = Quantity(f32);

    // Example:
    var print_buffer: [config.print_buffer_size]u8 = undefined;

    const one_second = Q32.init(1, seconds);

    const mass = Q32.init(10.5, kilograms);
    const distance_1 = Q32.init(10, meters);
    const distance_2 = Q32.init(30, meters);
    const delta_time = Q32.init(5, seconds);

    const side_1 = Q32.init(2, meters);
    const side_2 = Q32.init(2, meters);

    const velocity_1 = try Q32.combine(
        distance_1,
        one_second,
        .div,
        null,
        &registry,
        false,
    );

    const velocity_2 = try Q32.combine(
        distance_2,
        one_second,
        .div,
        null,
        &registry,
        false,
    );

    const delta_vel = try Q32.sub(velocity_2, velocity_1);

    const acceleration = try Q32.combine(
        delta_vel,
        delta_time,
        .div,
        "acceleration",
        &registry,
        false,
    );

    var force = try Q32.combine(
        mass,
        acceleration,
        .mul,
        "force",
        &registry,
        false,
    );
    try force.write(&print_buffer, &io);

    var square = try Q32.combine(
        side_1,
        side_2,
        .mul,
        "square",
        &registry,
        false,
    );
    try square.write(&print_buffer, &io);

    var pressure = try Q32.combine(
        force,
        square,
        .div,
        "pressure",
        &registry,
        true,
    );
    try pressure.write(&print_buffer, &io);
}
