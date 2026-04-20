const std = @import("std");

pub fn build(b: *std.Build) void {
    // const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});
    //
    // const lib = b.addLibrary(.{
    //     .name = "mcts_bot",
    //     .linkage = .dynamic,
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("src/main.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    //
    // lib.install_name = "@loader_path/libmcts_bot.dylib";
    //
    // lib.linkLibC();
    // lib.linkSystemLibrary("pthread");
    // b.installArtifact(lib);

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Shared module so both lib + exe use the same code
    const module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ---- Library ----
    const lib = b.addLibrary(.{
        .name = "mcts_bot",
        .linkage = .dynamic,
        .root_module = module,
    });

    lib.install_name = "@loader_path/libmcts_bot.dylib";
    lib.linkLibC();
    lib.linkSystemLibrary("pthread");
    b.installArtifact(lib);

    // ---- Executable ----
    const exe = b.addExecutable(.{
        .name = "mcts_bot_runner",
        .root_module = module,
    });

    exe.linkLibC();
    exe.linkSystemLibrary("pthread");

    b.installArtifact(exe);
}
