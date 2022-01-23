// Designed to be compiled with zig version 0.8.0

const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("drawbridge", "src/main.zig");
    exe.setBuildMode(mode);

    exe.addPackagePath("c", "src/c.zig");
    exe.addPackagePath("misc", "src/misc.zig");
    exe.addPackagePath("mot", "../mot/src/extras.zig"); // TODO put MOT on github and use it as a submodule within this dir
    exe.addPackagePath("queue", "../common/queue.zig"); // TODO put this on github and use it as a submodule within this dir
    exe.addPackagePath("parser", "../common/parser.zig"); // TODO put this on github and use it as a submodule within this dir

    const lib_cflags = [_][]const u8{"-std=c99"};
    exe.addCSourceFile("src/setpixel.c", lib_cflags[0..]);
    exe.addIncludeDir("src/");
    exe.linkSystemLibrary("c");
    exe.addIncludeDir("/usr/include/SDL2/");
    exe.linkSystemLibrary("SDL2");

    const run_cmd = exe.run();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
