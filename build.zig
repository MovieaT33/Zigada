const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    {
        const zsort = b.dependency("zsort", .{
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        });

        const zsort_exe = zsort.artifact("zsort");

        const run_fix = b.addRunArtifact(zsort_exe);
        run_fix.addArgs(&.{
            "fix",
            "src",
            "--ban-prefix",
            "./",
        });

        b.step(
            "fix-imports",
            "Fix Zig import ordering",
        ).dependOn(&run_fix.step);
    }

    {
        const exe = b.addExecutable(.{
            .name = "Zigada",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{},
            }),
        });

        b.installArtifact(exe);

        const run_step = b.step("run", "Run the app");

        const run_cmd = b.addRunArtifact(exe);
        run_step.dependOn(&run_cmd.step);

        run_cmd.step.dependOn(b.getInstallStep());
    }
}
