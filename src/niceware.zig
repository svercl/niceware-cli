const std = @import("std");
const ascii = std.ascii;
const math = std.math;
const mem = std.mem;
const os = std.os;
const sort = std.sort;
// NOTE(bms): this is named as such to avoid shadowing
const words_import = @import("words.zig");

pub const Error = error{
    // Expected even sized slice, got an odd one
    OddSize,
    // Word not in words list
    WordNotFound,
    // Size is greater than maxmimum allowed
    SizeTooLarge,
    // Size is smaller than minimum allowed
    SizeTooSmall,
} || mem.Allocator.Error;

// most recent not found word from [passphraseToBytes].
var word_not_found: ?[]const u8 = null;

const all_words = words_import.words;
const max_word_length = words_import.max_word_length;

pub const min_password_size = 2;
pub const max_password_size = 1024;

/// Returns the most recent not found word.
pub fn getWordNotFound() ?[]const u8 {
    return word_not_found;
}

/// Converts a byte array into a passphrase.
pub fn bytesToPassphrase(ally: *mem.Allocator, bytes: []const u8) ![][]const u8 {
    if (bytes.len < min_password_size) {
        return error.SizeTooSmall;
    } else if (bytes.len > max_password_size) {
        return error.SizeTooLarge;
    } else if (bytes.len % 2 != 0) {
        return error.OddSize;
    }

    var res = std.ArrayList([]const u8).init(ally);
    errdefer res.deinit();

    // this cannot error, because we already check if the size is even.
    var pairs_it = pairs(u8, bytes) catch unreachable;
    while (pairs_it.next()) |p| {
        const word_idx = mem.readInt(u16, &p, .Big);
        std.debug.assert(word_idx < all_words.len);
        try res.append(all_words[word_idx]);
    }

    return res.toOwnedSlice();
}

/// Converts a passphrase back into the original byte array.
pub fn passphraseToBytes(ally: *mem.Allocator, passphrase: []const []const u8) ![]u8 {
    var bytes = try std.ArrayList(u8).initCapacity(ally, passphrase.len * 2);
    errdefer bytes.deinit();
    var writer = bytes.writer();

    for (passphrase) |word| {
        // checks if the word is longer than any known word
        if (word.len > max_word_length) {
            word_not_found = word;
            return error.WordNotFound;
        }

        const word_idx = sort.binarySearch(
            []const u8,
            word,
            &all_words,
            {},
            struct {
                fn compare(context: void, a: []const u8, b: []const u8) math.Order {
                    _ = context;
                    return ascii.orderIgnoreCase(a, b);
                }
            }.compare,
        ) orelse {
            word_not_found = word;
            return error.WordNotFound;
        };
        try writer.writeIntBig(u16, @intCast(u16, word_idx));
    }

    return bytes.toOwnedSlice();
}

/// Generates a passphrase with the specified number of bytes.
// NOTE(bms): u11 is used here because u10 only goes up to 1023, but we need 1024.
pub fn generatePassphrase(ally: *mem.Allocator, size: u11) ![][]const u8 {
    // fills an array of bytes using system random (normally, this is cryptographically secure)
    var random_bytes = try ally.alloc(u8, size);
    try os.getrandom(random_bytes);
    return bytesToPassphrase(ally, random_bytes);
}

test "generates passphrases of the correct length" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try std.testing.expectEqual((try generatePassphrase(ally, 2)).len, 1);
    try std.testing.expectEqual((try generatePassphrase(ally, 20)).len, 10);
    try std.testing.expectEqual((try generatePassphrase(ally, 512)).len, 256);
}

test "errors when generating passphrase with an odd number of bytes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try std.testing.expectError(error.OddSize, generatePassphrase(ally, 3));
    try std.testing.expectError(error.OddSize, generatePassphrase(ally, 23));
}

test "errors when generating passphrases that are too large" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try std.testing.expectError(error.SizeTooLarge, generatePassphrase(ally, 1026));
}

test "errors when generating passphrases that are too small" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try std.testing.expectError(error.SizeTooSmall, generatePassphrase(ally, 1));
}

test "errors when byte array has odd length" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try std.testing.expectError(error.OddSize, bytesToPassphrase(ally, &[_]u8{0} ** 3));
}

test "bytes to passphrase expected" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try std.testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{"a"},
        try bytesToPassphrase(ally, &[_]u8{0} ** 2),
    );
    try std.testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{"zyzzyva"},
        try bytesToPassphrase(ally, &[_]u8{0xff} ** 2),
    );
    try std.testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{
            "a",
            "bioengineering",
            "balloted",
            "gobbledegook",
            "creneled",
            "written",
            "depriving",
            "zyzzyva",
        },
        try bytesToPassphrase(ally, &[_]u8{
            0x00,
            0x00,
            0x11,
            0xd4,
            0x0c,
            0x8c,
            0x5a,
            0xf7,
            0x2e,
            0x53,
            0xfe,
            0x3c,
            0x36,
            0xa9,
            0xff,
            0xff,
        }),
    );
}

test "errors when input is not in the wordlist" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try std.testing.expectError(
        error.WordNotFound,
        passphraseToBytes(ally, &[_][]const u8{ "You", "love", "ninetails" }),
    );
}

test "returns expected bytes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x00 },
        try passphraseToBytes(ally, &[_][]const u8{"A"}),
    );
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 0xff, 0xff },
        try passphraseToBytes(ally, &[_][]const u8{"zyzzyva"}),
    );
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{
            0x00,
            0x00,
            0x11,
            0xd4,
            0x0c,
            0x8c,
            0x5a,
            0xf7,
            0x2e,
            0x53,
            0xfe,
            0x3c,
            0x36,
            0xa9,
            0xff,
            0xff,
        },
        try passphraseToBytes(ally, &[_][]const u8{
            "a",
            "bioengineering",
            "balloted",
            "gobbledegook",
            "creneled",
            "written",
            "depriving",
            "zyzzyva",
        }),
    );
}

/// Returns an iterator over a slice [buf] in pairs of two.
fn pairs(comptime T: type, buf: []const T) !PairIterator(T) {
    if (buf.len % 2 != 0) return error.OddSize;
    return PairIterator(T).init(buf);
}

/// An iterator over pairs from a slice.
fn PairIterator(comptime T: type) type {
    return struct {
        buf: []const T,
        index: usize,

        const Self = @This();

        /// Creates a new [PairIterator] from a [buf].
        pub fn init(buf: []const T) Self {
            return .{
                .buf = buf,
                .index = 0,
            };
        }

        /// Resets the iterator to the beginning.
        pub fn reset(self: *Self) void {
            self.index = 0;
        }

        /// Returns the next pair or null when at the end of the slice.
        pub fn next(self: *Self) ?[2]T {
            if (self.index >= self.buf.len or self.index + 1 >= self.buf.len) {
                return null;
            } else {
                const p = [_]T{
                    self.buf[self.index + 0], // note(bms): adding zero for visual aid only
                    self.buf[self.index + 1],
                };
                self.index += 2;
                return p;
            }
        }
    };
}
