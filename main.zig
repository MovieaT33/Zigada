const std = @import("std");

const Dimension = @import("dimension.zig").Dimension;
const Quantity = @import("quantity.zig").Quantity;

pub fn main(init: std.process.Init) !void {
    const io = &init.io;

    // Initialize GPA.
    var gpa = std.heap.DebugAllocator(.{
        .safety = true,
    }){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    // Initialize dimensions.
    var kilograms = Dimension.init(&allocator);
    defer kilograms.deinit();

    var meters = Dimension.init(&allocator);
    defer meters.deinit();

    var seconds = Dimension.init(&allocator);
    defer seconds.deinit();

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
    var m = Q32.init(10, kilograms);
    const d1 = Q32.init(10, meters);
    const t1 = Q32.init(1, seconds);
    const d2 = Q32.init(30, meters);
    const t2 = Q32.init(1, seconds);
    var t = Q32.init(5, seconds);

    const s1 = Q32.init(2, meters);
    const s2 = Q32.init(2, meters);

    var v1 = try Q32.div(&d1, &t1);
    defer v1.dimension.deinit();

    var v2 = try Q32.div(&d2, &t2);
    defer v2.dimension.deinit();

    var dv = try Q32.sub(&v2, &v1);

    var a = try Q32.div(&dv, &t);
    defer a.dimension.deinit();

    var f = try Q32.mul(&m, &a);
    defer f.dimension.deinit();
    try f.show("force", &buffer, io);

    var s = try Q32.mul(&s1, &s2);
    defer s.dimension.deinit();
    try s.show("square", &buffer, io);

    var p = try Q32.div(&f, &s);
    defer p.dimension.deinit();
    try p.show("pressure", &buffer, io);
}
