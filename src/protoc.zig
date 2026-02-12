const std = @import("std");
const builtin = @import("builtin");
const protobuf = @import("protobuf");

pub const Protoc = struct {
    path: []const u8,
    step: *std.Build.Step,

    pub fn downloadProtocBinary(b: *std.Build) !Protoc {
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
            @panic("Platform not supported:" ++ builtin.os.tag);
        defer b.allocator.free(dependencyName);

        if (b.lazyDependency(dependencyName, .{})) |dep| {
            const path = if (builtin.os.tag == .windows) dep.path("bin/protoc.exe").getPath(b) else dep.path("bin/protoc").getPath(b);
            return Protoc{ .path = path, .step = dep.builder.default_step };
        }

        @panic("protoc dependency not found for platform");
    }

    pub fn findSystemProtoc(b: *std.Build) Protoc {
        const name = switch (builtin.os.tag) {
            .windows => Protoc{ .path = "protoc.exe" },
            .linux, .macos => Protoc{ .path = "protoc" },
            else => @panic("Platform not supported:" ++ builtin.os.tag),
        };

        const command = switch (builtin.os.tag) {
            .windows => "where.exe",
            .linux, .macos => "which",
            else => @panic("Platform not supported:" ++ builtin.os.tag),
        };

        const result = std.ChildProcess.exec(.{
            .allocator = std.heap.page_allocator,
            .argv = &.{ command, name },
        }) catch @panic("Failed to execute command: " ++ command);

        if (result.exit_code != 0) {
            @panic("Failed to find protoc: " ++ result.stderr);
        }

        const path = result.stdout.trim();

        if (path.len == 0) {
            @panic("Failed to find protoc: " ++ result.stderr);
        }

        return Protoc{ .path = path, .step = b.default_step };
    }

    pub fn buildProtocFromSources(b: *std.Build, target: std.Build.ResolvedTarget) Protoc {
        const optimize: std.builtin.OptimizeMode = .ReleaseFast;
        const protoc = b.dependency("protoc", .{ .target = target });
        const dep = protoc.builder.lazyDependency("protobuf_from_src", .{ .target = target, .optimize = optimize }) orelse @panic("unable to get protoc from src dep");
        const path = if (builtin.os.tag == .windows) dep.path("bin/protoc.exe").getPath(b) else dep.path("bin/protoc").getPath(b);
        return Protoc{ .path = path, .step = &dep.artifact("protoc").step };
    }
};
