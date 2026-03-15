const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "lib",
        .linkage = .dynamic,
        .version = .{ .major = 1, .minor = 2, .patch = 3 },
        .root_module = b.createModule(.{
            .root_source_file = b.path("fizzbuzz.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(lib);

    // const exe = b.addExecutable(.{
    //     .name = "uttt_bot",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("src/main.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    //
    // b.installArtifact(exe);
    //
    // const run_step = b.step("run", "Run the app");
    // const run_cmd = b.addRunArtifact(exe);
    // run_step.dependOn(&run_cmd.step);
    //
    // run_cmd.step.dependOn(b.getInstallStep());
}
