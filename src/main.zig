const std = @import("std");

const niceware = @import("niceware.zig");

const usage =
    \\Usage: niceware <command> [argument]
    \\
    \\Commands:
    \\  from-bytes    Convert bytes into a passphrase
    \\  to-bytes      Convert passphrase into bytes
    \\  generate      Generate a random passphrase
    \\
    \\General Options:
    \\  -h, --help    Print this message
    \\
;

const usage_from_bytes =
    \\Usage: niceware from-bytes [byte-string]
    \\
    \\Arguments:
    \\  [byte-string]    A hex string (example: 7a40bcb12c870b52)
    \\
    \\General Options:
    \\  -h, --help       Print this message
    \\
;

const usage_to_bytes =
    \\Usage: niceware to-bytes [passphrase]
    \\
    \\Arguments:
    \\  [passphrase]    A passphrase (example: legalize rich couch axel)
    \\
    \\General Options:
    \\  -h, --help      Print this message
    \\
;

const usage_generate =
    \\Usage: niceware generate [size]
    \\
    \\Arguments:
    \\  [size]    Amount of bytes to use (default: 8)
    \\
    \\General Options:
    \\  -h, --help      Print this message
    \\
;

// Determines if [what] is help, -h or --help.
fn isHelp(what: []const u8) bool {
    return std.mem.eql(u8, what, "help") or
        std.mem.eql(u8, what, "-h") or
        std.mem.eql(u8, what, "--help");
}

// Determines if the string contains only digits (base 10).
fn isStringNumeric(s: []const u8) bool {
    for (s) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }
    return true;
}

test "isStringNumeric" {
    try std.testing.expect(isStringNumeric("123"));
    try std.testing.expect(isStringNumeric("0123"));
}

test "!isStringNumeric" {
    try std.testing.expect(!isStringNumeric("+123"));
    try std.testing.expect(!isStringNumeric("numeric"));
}

fn generate(
    allocator: std.mem.Allocator,
    writer: anytype,
    args: [][]const u8,
) !void {
    if (args.len == 0) {
        const passphrase = try niceware.generatePassphraseAlloc(allocator, 8);
        // first line is the bytes
        const bytes = try niceware.passphraseToBytesAlloc(allocator, passphrase);
        try writer.print("{s}\n", .{std.fmt.fmtSliceHexLower(bytes)});
        // second line is the passphrase
        const joined = try std.mem.join(allocator, " ", passphrase);
        try writer.print("{s}\n", .{joined});
    } else if (args.len == 1) {
        const cmd = args[0];
        if (isHelp(cmd)) {
            try writer.writeAll(usage_generate);
        } else if (isStringNumeric(cmd)) {
            if (std.fmt.parseUnsigned(u11, cmd, 0)) |size| {
                if (niceware.generatePassphraseAlloc(allocator, size)) |passphrase| {
                    // first line is the bytes
                    const bytes = try niceware.passphraseToBytesAlloc(allocator, passphrase);
                    try writer.print("{s}\n", .{std.fmt.fmtSliceHexLower(bytes)});
                    // second line is the passphrase
                    const joined = try std.mem.join(allocator, " ", passphrase);
                    try writer.print("{s}\n", .{joined});
                } else |err| switch (err) {
                    error.SizeTooLarge,
                    error.SizeTooSmall,
                    => std.log.err("expected a number between {} and {}, got {}", .{
                        niceware.min_password_size,
                        niceware.max_password_size,
                        size,
                    }),
                    error.OddSize => std.log.err("expected an even number, got: {}", .{size}),
                    else => std.log.err("{}", .{err}),
                }
            } else |_| {
                std.log.err("invalid number: {s}", .{cmd});
            }
        } else {
            std.log.err("{s}", .{usage_generate});
            std.log.err("unknown command: {s}", .{cmd});
        }
    } else {
        try writer.writeAll(usage_generate);
    }
}

fn toBytes(allocator: std.mem.Allocator, writer: anytype, args: [][]const u8) !void {
    if (args.len >= 1) {
        const cmd = args[0];
        if (isHelp(cmd)) {
            try writer.writeAll(usage_to_bytes);
        } else {
            if (niceware.passphraseToBytesAlloc(allocator, args)) |bytes| {
                try writer.print("{s}\n", .{std.fmt.fmtSliceHexLower(bytes)});
            } else |err| switch (err) {
                error.WordNotFound => {
                    if (niceware.getWordNotFound()) |word| {
                        std.log.err("invalid word entered: {s}", .{word});
                    } else {
                        std.log.err("invalid word entered", .{});
                    }
                },
                else => std.log.err("{}", .{err}),
            }
        }
    } else {
        try writer.writeAll(usage_to_bytes);
    }
}

fn fromBytes(allocator: std.mem.Allocator, writer: anytype, args: [][]const u8) !void {
    if (args.len == 1) {
        const cmd = args[0];
        if (isHelp(cmd)) {
            try writer.writeAll(usage_from_bytes);
        } else {
            const size = cmd.len;
            if (size == 0) {
                std.log.err("input looks empty to me: {s}", .{cmd});
            } else if (size % 2 != 0) {
                std.log.err("input must be an even length, {} is not an even number", .{size});
            } else {
                const buf = try allocator.alloc(u8, size / 2);
                if (std.fmt.hexToBytes(buf, cmd)) |bytes| {
                    if (niceware.bytesToPassphraseAlloc(allocator, bytes)) |passphrase| {
                        const joined = try std.mem.join(allocator, " ", passphrase);
                        try writer.print("{s}\n", .{joined});
                    } else |err| switch (err) {
                        error.SizeTooSmall,
                        error.SizeTooLarge,
                        => std.log.err("", .{}),
                        error.OddSize => std.log.err("", .{}),
                        else => std.log.err("{}", .{err}),
                    }
                } else |_| {
                    std.log.err("unable to convert into passphrase: {s} (is this a valid hex string?)", .{cmd});
                }
            }
        }
    } else {
        try writer.writeAll(usage_from_bytes);
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const ally = arena.allocator();

    const stdout = std.io.getStdOut().writer();

    const args = try std.process.argsAlloc(ally);
    if (args.len <= 1) {
        try stdout.writeAll(usage);
        return;
    }

    const cmd = args[1];
    const cmd_args = args[2..];
    if (std.mem.eql(u8, cmd, "from-bytes")) {
        try fromBytes(ally, stdout, cmd_args);
    } else if (std.mem.eql(u8, cmd, "to-bytes")) {
        try toBytes(ally, stdout, cmd_args);
    } else if (std.mem.eql(u8, cmd, "generate")) {
        try generate(ally, stdout, cmd_args);
    } else if (isHelp(cmd)) {
        try stdout.writeAll(usage);
    } else {
        try stdout.writeAll(usage);
        std.log.err("unknown command: {s}", .{cmd});
    }
}
