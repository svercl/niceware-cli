const std = @import("std");
const ascii = std.ascii;
const math = std.math;
const mem = std.mem;
const os = std.os;
const sort = std.sort;

const words = @import("words.zig");
const wordlist = words.wordlist;
const max_word_length = words.max_word_length;

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

// most recent not found word for error reporting
var word_not_found: ?[]const u8 = null;

pub const min_password_size = 2;
pub const max_password_size = 1024;

/// Returns the most recent not found word.
pub fn getWordNotFound() ?[]const u8 {
    return word_not_found;
}

/// Compute the space needed to convert bytes into a passphrase.
pub fn passphraseSize(bytes: []const u8) !usize {
    if (bytes.len < min_password_size) {
        return error.SizeTooSmall;
    } else if (bytes.len > max_password_size) {
        return error.SizeTooBig;
    } else if (bytes.len % 2 != 0) {
        return error.OddSize;
    }

    // this cannot error, because we already check if the size is even
    var size: usize = 0;
    var i: usize = 0;
    while (i < bytes.len) : (i += 2) {
        const word_idx = mem.readInt(u16, &[_]u8{ bytes[i + 0], bytes[i + 1] }, .Big);

        size += wordlist[word_idx].len;
    }

    return size;
}

/// Converts a byte array into a passphrase. Use [passphraseSize] to compute an appropriate buffer size.
pub fn bytesToPassphrase(out: []u8, bytes: []const u8) !void {
    var fbs = std.io.fixedBufferStream(out);
    const writer = fbs.writer();

    var i: usize = 0;
    while (i < bytes.len) : (i += 2) {
        const word_idx = mem.readInt(u16, &[_]u8{ bytes[i + 0], bytes[i + 1] }, .Big);

        try writer.writeAll(wordlist[word_idx]);

        // only append a space if we are not at the last iteration
        if (i != bytes.len - 2) {
            try writer.writeByte(' ');
        }
    }
}

/// Converts a byte array into a passphrase.
pub fn bytesToPassphraseAlloc(ally: mem.Allocator, bytes: []const u8) ![][]const u8 {
    if (bytes.len < min_password_size) {
        return error.SizeTooSmall;
    } else if (bytes.len > max_password_size) {
        return error.SizeTooLarge;
    } else if (bytes.len % 2 != 0) {
        return error.OddSize;
    }

    // division is safe, because it's always even
    var res = try std.ArrayList([]const u8).initCapacity(ally, bytes.len / 2);
    errdefer res.deinit();

    var i: usize = 0;
    while (i < bytes.len) : (i += 2) {
        const word_idx = mem.readInt(u16, &[_]u8{ bytes[i + 0], bytes[i + 1] }, .big);

        res.appendAssumeCapacity(wordlist[word_idx]);
    }

    return res.toOwnedSlice();
}

/// Compute the space needed to convert a passphrase into bytes.
pub fn bytesSize(passphrase: []const []const u8) usize {
    return passphrase.len * 2;
}

/// Converts a passphrase back into the original byte array. Use [bytesSize] to compute an appropriate buffer size.
pub fn passphraseToBytes(out: []u8, passphrase: []const []const u8) !void {
    if (out.len != passphrase.len * 2) {
        return error.WrongSize;
    }

    var fbs = std.io.fixedBufferStream(out);
    const writer = fbs.writer();

    for (passphrase) |word| {
        // checks if the word is longer than any known word
        if (word.len > max_word_length) {
            word_not_found = word;
            return error.WordNotFound;
        }

        const word_idx = sort.binarySearch([]const u8, word, &wordlist, {}, struct {
            fn compare(_: void, a: []const u8, b: []const u8) math.Order {
                return ascii.orderIgnoreCase(a, b);
            }
        }.compare) orelse {
            word_not_found = word;
            return error.WordNotFound;
        };

        try writer.writeInt(u16, @intCast(word_idx), .big);
    }
}

/// Converts a passphrase back into the original byte array.
pub fn passphraseToBytesAlloc(ally: mem.Allocator, passphrase: []const []const u8) ![]u8 {
    const bytes = try ally.alloc(u8, passphrase.len * 2);
    errdefer ally.free(bytes);
    try passphraseToBytes(bytes, passphrase);
    return bytes;
}

/// Generates a passphrase with the specified number of bytes.
pub fn generatePassphraseAlloc(ally: mem.Allocator, size: u11) ![][]const u8 {
    // fills an array of bytes using system random (normally, this is cryptographically secure)
    const random_bytes = try ally.alloc(u8, size);
    errdefer ally.free(random_bytes);
    try os.getrandom(random_bytes);
    return bytesToPassphraseAlloc(ally, random_bytes);
}
