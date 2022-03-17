// Designed to be compiled with zig version 0.8.0

const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const executables = .{
        .{ "drawbridge", "src/client/main.zig" },
        .{ "drawbridge-server", "src/server/main.zig" },
    };

    inline for (executables) |i| {
        const exe = b.addExecutable(i[0], i[1]);
        exe.setBuildMode(mode);

        add_package_paths(exe);

        // Client only
        if (i[0].len == "drawbridge".len) {
            exe.addPackagePath("client", "src/client/index.zig");
            const lib_cflags = [_][]const u8{"-std=c99"};
            exe.addCSourceFile("src/client/setpixel.c", lib_cflags[0..]);
            // exe.addIncludeDir("src/");
            exe.addIncludeDir("/usr/include/SDL2/");
            exe.linkSystemLibrary("c");
            exe.linkSystemLibrary("SDL2");

            const run_cmd = exe.run();

            const run_step = b.step("run", "Run the app");
            run_step.dependOn(&run_cmd.step);
        }

        b.default_step.dependOn(&exe.step);
        b.installArtifact(exe);
    }

    const test_step = b.step("test", "Run tests");
    inline for ([_][]const u8{
        "src/net/index.zig",
        "src/client/net/outgoing.zig",
        "src/server/pack.zig",
        "src/server/management.zig",
    }) |testPath| {
        const test1 = b.addTest(testPath);
        test1.linkSystemLibrary("c");
        test1.addIncludeDir("/usr/include/SDL2/");

        test1.addPackagePath("client", "src/client/index.zig");
        add_package_paths(test1);

        test_step.dependOn(&test1.step);
    }
}

fn add_package_paths(exe: anytype) void {
    // Shared network code
    exe.addPackagePath("net", "src/net/index.zig");
    // Message Oriented Tcp
    exe.addPackagePath("mot", "../mot/src/extras.zig"); // TODO put MOT on github and use it as a submodule within this dir
    // Threadsafe queue
    exe.addPackagePath("queue", "../common/queue.zig"); // TODO put this on github and use it as a submodule within this dir
    // Command line parser
    exe.addPackagePath("parser", "../common/parser.zig"); // TODO put this on github and use it as a submodule within this dir
    // Packet serializer
    exe.addPackagePath("cereal", "../common/cereal.zig"); // TODO put this on github and use it as a submodule within this dir
}
