const std = @import("std");

const Dimension = @import("dimension.zig").Dimension;
const Dimensions = @import("dimensions.zig").Dimensions;
const Quantity = @import("quantity.zig").Quantity;

pub fn main(init: std.process.Init) !void {
    const io = &init.io;

    // Initialize GPA.
    var gpa = std.heap.DebugAllocator(.{
        .safety = true,
        .verbose_log = false,
    }){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    // Initialize dimensions.
    var dims = Dimensions.init(&allocator);
    defer {
        dims.show(io) catch unreachable;
        dims.deinit();
    }

    var kilograms = try Dimension.init("mass", &allocator);
    var meters = try Dimension.init("size", &allocator);
    var seconds = try Dimension.init("time", &allocator);

    try dims.add(kilograms, true);
    try dims.add(meters, true);
    try dims.add(seconds, true);

    // Add unit factors to dimensions.
    try kilograms.add(
        .{ .name = "kg", .power = 1 },
        .numerator,
    );

    try meters.add(
        .{ .name = "m", .power = 1 },
        .numerator,
    );

    try seconds.add(
        .{ .name = "s", .power = 1 },
        .numerator,
    );

    // Create a buffer.
    var buffer: [32]u8 = undefined;

    // Create a quantity type.
    const Q32 = Quantity(f32);

    // Example:
    const m = Q32.init(10, kilograms);
    const d1 = Q32.init(10, meters);
    const t1 = Q32.init(1, seconds);
    const d2 = Q32.init(30, meters);
    const t2 = Q32.init(1, seconds);
    const t = Q32.init(5, seconds);

    const s1 = Q32.init(2, meters);
    const s2 = Q32.init(2, meters);

    const v1 = try Q32.operate(
        d1,
        t1,
        .div,
        "v1",
        &dims,
        false,
    );

    const v2 = try Q32.operate(
        d2,
        t2,
        .div,
        "v2",
        &dims,
        false,
    );

    const dv = Q32.sub(v2, v1);

    const a = try Q32.operate(
        dv,
        t,
        .div,
        "a",
        &dims,
        false,
    );

    var f = try Q32.operate(
        m,
        a,
        .mul,
        "force",
        &dims,
        false,
    );
    try f.show(&buffer, io);

    var s = try Q32.operate(
        s1,
        s2,
        .mul,
        "square",
        &dims,
        false,
    );
    try s.show(&buffer, io);

    var p = try Q32.operate(
        f,
        s,
        .div,
        "pressure",
        &dims,
        true,
    );
    try p.show(&buffer, io);
}
