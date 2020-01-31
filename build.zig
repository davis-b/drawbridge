const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("drawbridge", "src/main.zig");
    exe.setBuildMode(mode);

    const lib_cflags = [_][]const u8{"-std=c99"};
    exe.addCSourceFile("src/setpixel.c", lib_cflags);
    exe.addIncludeDir("src/");
    exe.linkSystemLibrary("c");
    exe.addIncludeDir("/usr/include/SDL2/");
    //exe.linkFramework("SDL2");
    exe.linkSystemLibrary("SDL2");

    const run_cmd = exe.run();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
