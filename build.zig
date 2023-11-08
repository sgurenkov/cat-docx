const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const clap = b.addModule("clap", .{ .source_file = .{ .path = "libs/clap/clap.zig" } });

    const exe = b.addExecutable(.{
        .name = "docls",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("clap", clap);
    b.installArtifact(exe);

    //
    // build and run: `zig build run`
    //
    const run_step = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_step.addArgs(args);
    }

    const step = b.step("run", "Runs the executable");
    step.dependOn(&run_step.step);

    //
    // wasm artifact: zig build
    //
    var wasm = b.addSharedLibrary(.{
        .name = "docls",
        .root_source_file = .{ .path = "src/wasm.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    wasm.import_memory = true;
    // wasm.max_memory = 25 * 1024 * 1024;
    // wasm.global_base = 65000;

    wasm.rdynamic = true;
    const install_wasm_step = b.addInstallArtifact(wasm, .{});

    const wasm_step = b.step("wasm", "Build wasm artifact");
    wasm_step.dependOn(&install_wasm_step.step);

    //
    // tests
    //
    const tests = b.addTest(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
    });

    tests.addModule("clap", clap);

    const test_cmd = b.addRunArtifact(tests);
    test_cmd.step.dependOn(b.getInstallStep());
    const test_step = b.step("test", "Run the tests");
    test_step.dependOn(&test_cmd.step);
}
