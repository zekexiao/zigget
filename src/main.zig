const std = @import("std");
const utils = @import("utils.zig");

pub const Options = struct {
    url: []const u8,
};

pub fn printHelp() void {
    std.debug.print("install username/repo, for install a repo\n", .{});
    std.debug.print("update username/repo, for update a repo\n", .{});
    std.debug.print("remove username/repo, for remove a repo\n", .{});
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

    const home_dir = try std.mem.concat(allocator, u8, &.{ std.os.getenv("HOME") orelse "", "/.zigget/" });
    defer allocator.free(home_dir);
    if (!(try utils.fileExist(home_dir))) {
        try std.fs.cwd().makeDir(home_dir);
    }

    const source_dir = try std.mem.concat(allocator, u8, &.{ std.os.getenv("HOME") orelse "", "/.zigget/source/" });
    defer allocator.free(source_dir);
    if (!(try utils.fileExist(source_dir))) {
        try std.fs.cwd().makeDir(source_dir);
    }

    const bin_dir = try std.mem.concat(allocator, u8, &.{ std.os.getenv("HOME") orelse "", "/.zigget/bin/" });
    defer allocator.free(bin_dir);
    if (!(try utils.fileExist(bin_dir))) {
        try std.fs.cwd().makeDir(bin_dir);
    }

    if (std.mem.eql(u8, arg1, "install")) {
        if (argv.len < 3) {
            printHelp();
            return;
        }
        var arg2 = argv[2];
        const url = try std.mem.concat(allocator, u8, &.{ "https://github.com/", arg2 });
        defer allocator.free(url);
        const dir = try std.mem.concat(allocator, u8, &.{ source_dir, arg2 });
        defer allocator.free(dir);
        if (!(try utils.fileExist(dir))) {
            std.debug.print("--- git clone ---\n", .{});
            try utils.execCommand(allocator, &.{ "git", "clone", url, dir }, null);
        } else {
            std.debug.print("{s} already installed\n", .{arg2});
            return;
        }
        std.debug.print("--- zig build ---\n", .{});
        try utils.execCommand(allocator, &.{ "zig", "build", "-Doptimize=ReleaseSafe", "-fsummary" }, dir);

        const zig_out_dir =
            try std.mem.concat(allocator, u8, &.{ dir, "/zig-out/bin/" });
        defer allocator.free(zig_out_dir);
        std.debug.print("{s} installed\n", .{arg2});
        try utils.createAllSymlink(allocator, zig_out_dir, bin_dir);
    } else if (std.mem.eql(u8, arg1, "update")) {
        if (argv.len < 3) {
            printHelp();
            return;
        }
        var arg2 = argv[2];
        const dir = try std.mem.concat(allocator, u8, &.{ source_dir, arg2 });
        defer allocator.free(dir);
        if (try utils.fileExist(dir)) {
            std.debug.print("--- git reset and pull ---\n", .{});
            try utils.execCommand(allocator, &.{
                "git",
                "fetch",
                "--all",
            }, dir);
            try utils.execCommand(allocator, &.{ "git", "reset", "--hard", "origin/master" }, dir);
            try utils.execCommand(allocator, &.{ "git", "pull" }, dir);
        } else {
            std.debug.print("{s} not installed\n", .{arg2});
            return;
        }
        std.debug.print("--- zig build ---\n", .{});
        try utils.execCommand(allocator, &.{ "zig", "build", "-Doptimize=ReleaseSafe", "-fsummary" }, dir);

        const zig_out_dir = try std.mem.concat(allocator, u8, &.{ dir, "/zig-out/bin/" });
        defer allocator.free(zig_out_dir);
        try utils.createAllSymlink(allocator, zig_out_dir, bin_dir);
        std.debug.print("{s} up to date\n", .{arg2});
    } else if (std.mem.eql(u8, arg1, "list")) {
        var pkg_source_dir = try std.fs.cwd().openIterableDir(source_dir, .{});
        var it = pkg_source_dir.iterate();
        while (try it.next()) |dir| {
            if (dir.kind != .directory) {
                continue;
            }
            const user_dir = try std.mem.concat(allocator, u8, &.{ source_dir, dir.name });
            defer allocator.free(user_dir);
            var repo_dir = try std.fs.cwd().openIterableDir(user_dir, .{});
            var repo_it = repo_dir.iterate();
            while (try repo_it.next()) |repo| {
                if (repo.kind != .directory) {
                    continue;
                }
                std.debug.print("{s}/{s}\n", .{ dir.name, repo.name });
            }
        }
    } else if (std.mem.eql(u8, arg1, "remove")) {
        if (argv.len < 3) {
            printHelp();
            return;
        }
        var pkgName = argv[2];
        const dir = try std.mem.concat(allocator, u8, &.{ source_dir, pkgName, "/" });
        defer allocator.free(dir);
        try std.fs.cwd().deleteTree(dir);
        // TODO, remove symblink
    } else {
        printHelp();
    }
}
