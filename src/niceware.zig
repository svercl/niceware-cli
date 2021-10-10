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
pub fn get_word_not_found() ?[]const u8 {
    return word_not_found;
}

// Converts a byte array into a passphrase.
pub fn bytes_to_passphrase(ally: *mem.Allocator, bytes: []const u8) ![][]const u8 {
    if (bytes.len < min_password_size) return error.SizeTooSmall;
    if (bytes.len > max_password_size) return error.SizeTooLarge;
    if (bytes.len % 2 != 0) return error.OddSize;

    var res = std.ArrayList([]const u8).init(ally);
    // edge-case on zero length slices
    if (bytes.len == 0) {
        return res.toOwnedSlice();
    }

    // iterate in pairs
    for (bytes) |byte, idx| {
        if (idx % 2 != 0) continue;
        const next = @intCast(u16, bytes[idx + 1]);
        const word_idx = @intCast(u16, byte) * 256 + next;
        std.debug.assert(word_idx < all_words.len);
        try res.append(all_words[word_idx]);
    }

    return res.toOwnedSlice();
}

// Converts a phrase back into the original byte array.
pub fn passphrase_to_bytes(ally: *mem.Allocator, words: [][]const u8) ![]u8 {
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
pub fn generate_passphrase(ally: *mem.Allocator, size: u11) ![][]const u8 {
    if (size < min_password_size) return error.SizeTooSmall;
    if (size > max_password_size) return error.SizeTooLarge;
    if (size % 2 != 0) return error.OddSize;
    var random_bytes = try ally.alloc(u8, size);
    try os.getrandom(random_bytes);
    return bytes_to_passphrase(ally, random_bytes);
}

test "correct_passphrase_length" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;

    try t.expectEqual((try generate_passphrase(ally, 2)).len, 1);
    try t.expectEqual((try generate_passphrase(ally, 20)).len, 10);
    try t.expectEqual((try generate_passphrase(ally, 512)).len, 256);
}
