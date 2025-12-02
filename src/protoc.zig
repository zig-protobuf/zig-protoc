const std = @import("std");
const builtin = @import("builtin");

pub const Protoc = struct {
    path: []const u8,
};

pub fn downloadProtocBinary(b: *std.Build) Protoc {
    const os: ?[]const u8 = switch (builtin.os.tag) {
        .macos => "osx",
        .linux => "linux",
        else => null,
    };

    const arch: ?[]const u8 = switch (builtin.cpu.arch) {
        .powerpcle, .powerpc64le => "ppcle",
        .aarch64, .aarch64_be => "aarch_64",
        .s390x => "s390",
        .x86_64 => "x86_64",
        .x86 => "x86_32",
        else => null,
    };

    const dependencyName = if (builtin.os.tag == .windows)
        try std.mem.concat(b.allocator, u8, &.{"protoc-win64"})
    else if (os != null and arch != null)
        try std.mem.concat(b.allocator, u8, &.{ "protoc-", os.?, "-", arch.? })
    else
        @panic("Platform not supported");
    defer b.allocator.free(dependencyName);

    if (b.lazyDependency(dependencyName, .{})) |dep| {
        const path = if (builtin.os.tag == .windows) dep.path("bin/protoc.exe").getPath(b) else dep.path("bin/protoc").getPath(b);
        return Protoc{ .path = path };
    }

    @panic("protoc dependency not found for platform: " ++ builtin.os.tag.name ++ " and architecture: " ++ builtin.cpu.arch.name);
}

pub fn findSystemProtoc() Protoc {
    const name = switch (builtin.os.tag) {
        .windows => Protoc{ .path = "protoc.exe" },
        .linux, .macos => Protoc{ .path = "protoc" },
        else => @panic("Platform not supported"),
    };

    const command = switch (builtin.os.tag) {
        .windows => "where.exe",
        .linux, .macos => "which",
        else => @panic("Platform not supported"),
    };

    const result = std.ChildProcess.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &.{ command, name },
    }) catch @panic("Failed to execute command: " ++ command);

    if (result.exit_code != 0) {
        @panic("Failed to find protoc: " ++ result.stderr);
    }

    const path = result.stdout.trim();

    if(path.len == 0) {
        @panic("Failed to find protoc: " ++ result.stderr);
    }

    return Protoc{ .path = path };
}
