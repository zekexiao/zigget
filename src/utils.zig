const std = @import("std");

pub fn fileExist(fileName: []const u8) !bool {
    std.fs.cwd().access(fileName, .{}) catch |e| switch (e) {
        error.FileNotFound => return false,
        else => return error.UnexpectedError,
    };
    return true;
}

pub fn createAllSymlink(allocator: std.mem.Allocator, fromDir: []const u8, distDir: []const u8) !void {
    var out_dir = try std.fs.cwd().openIterableDir(fromDir, .{});
    var it = out_dir.iterate();
    while (try it.next()) |file| {
        if (file.kind != .File) {
            continue;
        }
        const filePath = try std.mem.concat(allocator, u8, &.{ fromDir, file.name });
        defer allocator.free(filePath);
        const distPath = try std.mem.concat(allocator, u8, &.{ distDir, file.name });
        defer allocator.free(distPath);
        if (try fileExist(distPath)) {
            try std.fs.cwd().deleteFile(distPath);
        }

        try std.os.symlink(filePath, distPath);
    }
}

pub fn execCommand(allocator: std.mem.Allocator, argv: []const []const u8, cwd: ?[]const u8) !void {
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();
    var ec = try std.ChildProcess.exec(.{ .allocator = allocator, .argv = argv, .expand_arg0 = .expand, .env_map = &env, .cwd = cwd });
    defer {
        allocator.free(ec.stderr);
        allocator.free(ec.stdout);
    }
    std.debug.print("{s}", .{ec.stdout});
    std.debug.print("{s}", .{ec.stderr});
    if (ec.term.Exited != 0) {
        return error.ExecExitedFailed;
    }
}
