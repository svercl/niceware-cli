const std = @import("std");
const testing = std.testing;
const niceware = @import("niceware.zig");

test "bytes to passphrase does not allocate internally" {
    const bytes = &[_]u8{ 0x00, 0x00 };
    const size = niceware.passphraseSize(bytes) catch unreachable;
    var buf = try testing.allocator.alloc(u8, size);
    defer testing.allocator.free(buf);
    try niceware.bytesToPassphrase(buf, bytes);
    try testing.expectEqualStrings(buf, "a");
}

test "passphrase to bytes does not allocate internally" {
    const passphrase = &[_][]const u8{"zyzzyva"};
    const size = niceware.bytesSize(passphrase);
    var buf = try testing.allocator.alloc(u8, size);
    defer testing.allocator.free(buf);
    try niceware.passphraseToBytes(buf, passphrase);
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0xff, 0xff },
        buf,
    );
}

test "generates passphrases of the correct length" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectEqual(@as(usize, 1), (try niceware.generatePassphraseAlloc(ally, 2)).len);
    try testing.expectEqual(@as(usize, 10), (try niceware.generatePassphraseAlloc(ally, 20)).len);
    try testing.expectEqual(@as(usize, 256), (try niceware.generatePassphraseAlloc(ally, 512)).len);
}

test "errors when generating passphrase with an odd number of bytes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectError(error.OddSize, niceware.generatePassphraseAlloc(ally, 3));
    try testing.expectError(error.OddSize, niceware.generatePassphraseAlloc(ally, 23));
}

test "errors when generating passphrases that are too large" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectError(error.SizeTooLarge, niceware.generatePassphraseAlloc(ally, 1026));
}

test "errors when generating passphrases that are too small" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectError(error.SizeTooSmall, niceware.generatePassphraseAlloc(ally, 1));
}

test "errors when byte array has odd length" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectError(error.OddSize, niceware.bytesToPassphraseAlloc(ally, &[_]u8{0} ** 3));
}

test "bytes to passphrase expected" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{"a"},
        try niceware.bytesToPassphraseAlloc(ally, &[_]u8{0} ** 2),
    );
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{"zyzzyva"},
        try niceware.bytesToPassphraseAlloc(ally, &[_]u8{0xff} ** 2),
    );
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{ "a", "bioengineering", "balloted", "gobbledegook", "creneled", "written", "depriving", "zyzzyva" },
        try niceware.bytesToPassphraseAlloc(
            ally,
            &[_]u8{ 0x00, 0x00, 0x11, 0xd4, 0x0c, 0x8c, 0x5a, 0xf7, 0x2e, 0x53, 0xfe, 0x3c, 0x36, 0xa9, 0xff, 0xff },
        ),
    );
}

test "errors when input is not in the wordlist" {
    var buf: [6]u8 = undefined;
    try testing.expectError(
        error.WordNotFound,
        niceware.passphraseToBytes(&buf, &[_][]const u8{ "You", "love", "ninetails" }),
    );
}

test "returns expected bytes" {
    {
        var buf: [2]u8 = undefined;
        try niceware.passphraseToBytes(&buf, &[_][]const u8{"A"});
        try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x00 }, &buf);
    }
    {
        var buf: [2]u8 = undefined;
        try niceware.passphraseToBytes(&buf, &[_][]const u8{"zyzzyva"});
        try testing.expectEqualSlices(u8, &[_]u8{ 0xff, 0xff }, &buf);
    }
    {
        var buf: [16]u8 = undefined;
        try niceware.passphraseToBytes(&buf, &[_][]const u8{ "a", "bioengineering", "balloted", "gobbledegook", "creneled", "written", "depriving", "zyzzyva" });
        try testing.expectEqualSlices(
            u8,
            &[_]u8{ 0x00, 0x00, 0x11, 0xd4, 0x0c, 0x8c, 0x5a, 0xf7, 0x2e, 0x53, 0xfe, 0x3c, 0x36, 0xa9, 0xff, 0xff },
            &buf,
        );
    }
}
