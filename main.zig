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
    var Meters = Dimension.init(&allocator);
    defer Meters.deinit();

    var Kilograms = Dimension.init(&allocator);
    defer Kilograms.deinit();

    // Add unit factors to dimensions.
    try Meters.add(
        .{ .name = "m", .power = 1 },
        .numerator,
    );

    try Kilograms.add(
        .{ .name = "kg", .power = 1 },
        .numerator,
    );

    // Create a quantity type.
    const F32 = Quantity(f32);

    var side = F32.init(10, Meters);
    try side.show(io);

    var squared_side = try F32.mul(&side, &side);
    defer squared_side.dimension.deinit();
    try squared_side.show(io);

    var volume = try F32.mul(&squared_side, &side);
    defer volume.dimension.deinit();
    try volume.show(io);
}
