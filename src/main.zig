const std = @import("std");
const clap = @import("clap");

pub const Options = struct {
    url: []const u8,
};

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

pub fn printHelp() void {
    std.debug.print("install username/repo, for install a repo\n", .{});
    std.debug.print("update username/repo, for update a repo\n", .{});
    std.debug.print("list, for list all of installed repo\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    if (argv.len < 2) {
        printHelp();
        return;
    }

    const arg1 = argv[1];
    if (std.mem.eql(u8, arg1, "help")) {
        printHelp();
        return;
    }

    const sourceDir = try std.mem.concat(allocator, u8, &.{ std.os.getenv("HOME") orelse "", "/.zigInstall/source/" });
    defer allocator.free(sourceDir);
    const binDir = try std.mem.concat(allocator, u8, &.{ std.os.getenv("HOME") orelse "", "/.zigInstall/bin/" });
    defer allocator.free(binDir);

    if (std.mem.eql(u8, arg1, "install")) {
        if (argv.len < 3) {
            printHelp();
            return;
        }
        var arg2 = argv[2];
        const url = try std.mem.concat(allocator, u8, &.{ "https://github.com/", arg2 });
        defer allocator.free(url);
        const dir = try std.mem.concat(allocator, u8, &.{ sourceDir, arg2 });
        defer allocator.free(dir);
        if (!(try fileExist(dir))) {
            std.debug.print("--- git clone ---\n", .{});
            try execCommand(allocator, &.{ "git", "clone", url, dir }, null);
        } else {
            std.debug.print("{s} already installed\n", .{arg2});
            return;
        }
        std.debug.print("--- zig build ---\n", .{});
        try execCommand(allocator, &.{ "zig", "build", "-Doptimize=ReleaseSafe", "-fsummary" }, dir);

        const zig_out_dir =
            try std.mem.concat(allocator, u8, &.{ dir, "/zig-out/bin/" });
        defer allocator.free(zig_out_dir);
        std.debug.print("{s} installed\n", .{arg2});
        try createAllSymlink(allocator, zig_out_dir, binDir);
    } else if (std.mem.eql(u8, arg1, "update")) {
        if (argv.len < 3) {
            printHelp();
            return;
        }
        var arg2 = argv[2];
        const dir = try std.mem.concat(allocator, u8, &.{ sourceDir, arg2 });
        defer allocator.free(dir);
        if (try fileExist(dir)) {
            std.debug.print("--- git reset and pull ---\n", .{});
            try execCommand(allocator, &.{
                "git",
                "fetch",
                "--all",
            }, dir);
            try execCommand(allocator, &.{ "git", "reset", "--hard", "origin/master" }, dir);
            try execCommand(allocator, &.{ "git", "pull" }, dir);
        } else {
            std.debug.print("{s} not installed\n", .{arg2});
            return;
        }
        std.debug.print("--- zig build ---\n", .{});
        try execCommand(allocator, &.{ "zig", "build", "-Doptimize=ReleaseSafe", "-fsummary" }, dir);

        const zig_out_dir = try std.mem.concat(allocator, u8, &.{ dir, "/zig-out/bin/" });
        defer allocator.free(zig_out_dir);
        try createAllSymlink(allocator, zig_out_dir, binDir);
        std.debug.print("{s} up to date\n", .{arg2});
    } else if (std.mem.eql(u8, arg1, "list")) {
        var source_dir = try std.fs.cwd().openIterableDir(sourceDir, .{});
        var it = source_dir.iterate();
        while (try it.next()) |dir| {
            if (dir.kind != .Directory) {
                continue;
            }
            const user_dir = try std.mem.concat(allocator, u8, &.{ sourceDir, dir.name });
            defer allocator.free(user_dir);
            var repo_dir = try std.fs.cwd().openIterableDir(user_dir, .{});
            var repo_it = repo_dir.iterate();
            while (try repo_it.next()) |repo| {
                if (repo.kind != .Directory) {
                    continue;
                }
                std.debug.print("{s}/{s}\n", .{ dir.name, repo.name });
            }
        }
    }
}
