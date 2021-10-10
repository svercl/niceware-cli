const std = @import("std");
const ascii = std.ascii;
const math = std.math;
const mem = std.mem;
const os = std.os;
const sort = std.sort;

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

// The most recent not found word from [passphrase_to_bytes].
var word_not_found: ?[]const u8 = null;
// entire words list
const all_words = @import("words.zig").words;

pub const min_password_size = 2;
pub const max_password_size = 1024;

// Returns the most recent not found word.
pub fn getWordNotFound() ?[]const u8 {
    return word_not_found;
}

// Converts a byte array into a passphrase.
pub fn bytesToPassphrase(ally: *mem.Allocator, bytes: []const u8) ![][]const u8 {
    if (bytes.len < min_password_size) {
        return error.SizeTooSmall;
    } else if (bytes.len > max_password_size) {
        return error.SizeTooLarge;
    } else if (bytes.len % 2 != 0) {
        return error.OddSize;
    }

    var res = std.ArrayList([]const u8).init(ally);
    // edge-case on zero length slices
    if (bytes.len == 0) {
        return res.toOwnedSlice();
    }

    // this cannot error, because we already check if the size is even
    var pairs_it = pairs(u8, bytes) catch unreachable;
    while (pairs_it.next()) |p| {
        const word_idx = @intCast(u16, p.first) * 256 + @intCast(u16, p.second);
        std.debug.assert(word_idx < all_words.len);
        try res.append(all_words[word_idx]);
    }

    return res.toOwnedSlice();
}

// Converts a phrase back into the original byte array.
pub fn passphraseToBytes(ally: *mem.Allocator, words: [][]const u8) ![]u8 {
    var bytes = try ally.alloc(u8, words.len * 2);

    for (words) |word, idx| {
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

        bytes[2 * idx + 0] = @intCast(u8, word_idx / 256);
        bytes[2 * idx + 1] = @intCast(u8, word_idx % 256);
    }

    return bytes;
}

// Generates a passphrase with the specified number of bytes.
pub fn generatePassphrase(ally: *mem.Allocator, size: u11) ![][]const u8 {
    var random_bytes = try ally.alloc(u8, size);
    try os.getrandom(random_bytes);
    return bytesToPassphrase(ally, random_bytes);
}

test "correct passphrase length" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;

    try t.expectEqual((try generatePassphrase(ally, 2)).len, 1);
    try t.expectEqual((try generatePassphrase(ally, 20)).len, 10);
    try t.expectEqual((try generatePassphrase(ally, 512)).len, 256);
}

/// Returns an iterator over a slice [buf] in pairs of two.
fn pairs(comptime T: type, buf: []const T) !PairIterator(T) {
    if (buf.len % 2 != 0) return error.OddSize;
    return PairIterator(T).init(buf);
}

/// A pair of a single type.
fn Pair(comptime T: type) type {
    return struct {
        first: T,
        second: T,
    };
}

/// Constructs a pair of a single type.
fn pair(comptime T: type, first: T, second: T) Pair(T) {
    return .{
        .first = first,
        .second = second,
    };
}

/// An iterator over pairs.
fn PairIterator(comptime T: type) type {
    return struct {
        buf: []const T,
        index: usize,

        const Self = @This();

        pub fn init(buf: []const T) Self {
            return .{
                .buf = buf,
                .index = 0,
            };
        }

        /// Returns the next pair or null when at the end of the slice.
        pub fn next(self: *Self) ?Pair(T) {
            if (self.index >= self.buf.len or self.index + 1 >= self.buf.len) {
                return null;
            } else {
                const next_index = self.index + 1;
                const p = pair(
                    T,
                    self.buf[self.index],
                    self.buf[next_index],
                );
                self.index += 1;
                return p;
            }
        }
    };
}
