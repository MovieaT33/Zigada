const std = @import("std");

const config = @import("config.zig");
const Dimension = @import("dimension.zig").Dimension;
const Dimensions = @import("dimensions.zig").Dimensions;
const Quantity = @import("quantity.zig").Quantity;

pub fn main(init: std.process.Init) !void {
    const io = &init.io;

    // Initialize GPA
    var gpa = std.heap.DebugAllocator(.{
        .safety = true,
    }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    // Initialize dimensions list
    var dims = Dimensions.init(allocator);
    defer {
        var stdout = std.Io.File.stdout();
        stdout.writePositionalAll(init.io, "\n", 0) catch unreachable;

        dims.write(io) catch unreachable;

        dims.deinit();
    }

    // Initialize base dimensions
    var kilograms = try Dimension.init("mass", allocator);
    var meters = try Dimension.init("size", allocator);
    var seconds = try Dimension.init("time", allocator);

    // Add unit factors to dimensions
    try kilograms.addFactor(
        .{ .name = "kg", .power = 1 },
        .numerator,
    );

    try meters.addFactor(
        .{ .name = "m", .power = 1 },
        .numerator,
    );

    try seconds.addFactor(
        .{ .name = "s", .power = 1 },
        .numerator,
    );

    // Initialize complex dimensions
    const velocity = try Dimension.combine(
        meters,
        seconds,
        .div,
        "velocity",
        false,
    );

    // Add dimensions to list
    try dims.append(kilograms);
    try dims.append(meters);
    try dims.append(seconds);
    try dims.append(velocity);

    // Create a quantity type
    const Q32 = Quantity(f32);

    // Example:
    var buffer: [config.print_buffer_size]u8 = undefined;

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
        &dims,
        false,
    );

    const velocity_2 = try Q32.combine(
        distance_2,
        one_second,
        .div,
        null,
        &dims,
        false,
    );

    const delta_vel = Q32.sub(velocity_2, velocity_1);

    const acceleration = try Q32.combine(
        delta_vel,
        delta_time,
        .div,
        "acceleration",
        &dims,
        false,
    );

    var force = try Q32.combine(
        mass,
        acceleration,
        .mul,
        "force",
        &dims,
        false,
    );
    try force.write(&buffer, io);

    var square = try Q32.combine(
        side_1,
        side_2,
        .mul,
        "square",
        &dims,
        false,
    );
    try square.write(&buffer, io);

    var pressure = try Q32.combine(
        force,
        square,
        .div,
        "pressure",
        &dims,
        true,
    );
    try pressure.write(&buffer, io);
}
