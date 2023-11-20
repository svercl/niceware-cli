const std = @import("std");
const ascii = std.ascii;
const fmt = std.fmt;
const heap = std.heap;
const io = std.io;
const log = std.log;
const mem = std.mem;
const process = std.process;
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
    return mem.eql(u8, what, "help") or mem.eql(u8, what, "-h") or mem.eql(u8, what, "--help");
}

// Determines if the string contains only digits (base 10).
fn isStringNumeric(s: []const u8) bool {
    for (s) |c| {
        // if any character is a non-digit, then it's not all digits
        if (!ascii.isDigit(c)) return false;
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

fn generate(ally: mem.Allocator, writer: anytype, args: [][]const u8) !void {
    if (args.len == 0) {
        const passphrase = try niceware.generatePassphraseAlloc(ally, 8);
        // first line is the bytes
        const bytes = try niceware.passphraseToBytesAlloc(ally, passphrase);
        try writer.print("{s}\n", .{fmt.fmtSliceHexLower(bytes)});
        // second line is the passphrase
        const joined = try mem.join(ally, " ", passphrase);
        try writer.print("{s}\n", .{joined});
    } else if (args.len == 1) {
        const cmd = args[0];
        if (isHelp(cmd)) {
            try writer.writeAll(usage_generate);
        } else if (isStringNumeric(cmd)) {
            if (fmt.parseUnsigned(u11, cmd, 0)) |size| {
                if (niceware.generatePassphraseAlloc(ally, size)) |passphrase| {
                    // first line is the bytes
                    const bytes = try niceware.passphraseToBytesAlloc(ally, passphrase);
                    try writer.print("{s}\n", .{fmt.fmtSliceHexLower(bytes)});
                    // second line is the passphrase
                    const joined = try mem.join(ally, " ", passphrase);
                    try writer.print("{s}\n", .{joined});
                } else |err| switch (err) {
                    error.SizeTooLarge,
                    error.SizeTooSmall,
                    => log.err("expected a number between {} and {}, got {}", .{
                        niceware.min_password_size,
                        niceware.max_password_size,
                        size,
                    }),
                    error.OddSize => log.err("expected an even number, got: {}", .{size}),
                    else => log.err("{}", .{err}),
                }
            } else |_| {
                log.err("invalid number: {s}", .{cmd});
            }
        } else {
            log.err("{s}", .{usage_generate});
            log.err("unknown command: {s}", .{cmd});
        }
    } else {
        try writer.writeAll(usage_generate);
    }
}

fn toBytes(ally: mem.Allocator, writer: anytype, args: [][]const u8) !void {
    if (args.len >= 1) {
        const cmd = args[0];
        if (isHelp(cmd)) {
            try writer.writeAll(usage_to_bytes);
        } else {
            if (niceware.passphraseToBytesAlloc(ally, args)) |bytes| {
                try writer.print("{s}\n", .{fmt.fmtSliceHexLower(bytes)});
            } else |err| switch (err) {
                error.WordNotFound => {
                    if (niceware.getWordNotFound()) |word| {
                        log.err("invalid word entered: {s}", .{word});
                    } else {
                        log.err("invalid word entered", .{});
                    }
                },
                else => log.err("{}", .{err}),
            }
        }
    } else {
        try writer.writeAll(usage_to_bytes);
    }
}

fn fromBytes(ally: mem.Allocator, writer: anytype, args: [][]const u8) !void {
    if (args.len == 1) {
        const cmd = args[0];
        if (isHelp(cmd)) {
            try writer.writeAll(usage_from_bytes);
        } else {
            const size = cmd.len;
            if (size == 0) {
                log.err("input looks empty to me: {s}", .{cmd});
            } else if (size % 2 != 0) {
                log.err("input must be an even length, {} is not an even number", .{size});
            } else {
                const buf = try ally.alloc(u8, size / 2);
                if (fmt.hexToBytes(buf, cmd)) |bytes| {
                    if (niceware.bytesToPassphraseAlloc(ally, bytes)) |passphrase| {
                        const joined = try mem.join(ally, " ", passphrase);
                        try writer.print("{s}\n", .{joined});
                    } else |err| switch (err) {
                        error.SizeTooSmall,
                        error.SizeTooLarge,
                        => log.err("", .{}),
                        error.OddSize => log.err("", .{}),
                        else => log.err("{}", .{err}),
                    }
                } else |_| {
                    log.err("unable to convert into passphrase: {s} (is this a valid hex string?)", .{cmd});
                }
            }
        }
    } else {
        try writer.writeAll(usage_from_bytes);
    }
}

pub fn main() anyerror!void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const ally = arena.allocator();

    const stdout = io.getStdOut().writer();

    const args = try process.argsAlloc(ally);
    if (args.len <= 1) {
        try stdout.writeAll(usage);
        return;
    }

    const cmd = args[1];
    const cmd_args = args[2..];
    if (mem.eql(u8, cmd, "from-bytes")) {
        try fromBytes(ally, stdout, cmd_args);
    } else if (mem.eql(u8, cmd, "to-bytes")) {
        try toBytes(ally, stdout, cmd_args);
    } else if (mem.eql(u8, cmd, "generate")) {
        try generate(ally, stdout, cmd_args);
    } else if (isHelp(cmd)) {
        try stdout.writeAll(usage);
    } else {
        try stdout.writeAll(usage);
        log.err("unknown command: {s}", .{cmd});
    }
}
