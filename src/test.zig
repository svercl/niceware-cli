const std = @import("std");
const testing = std.testing;
const niceware = @import("niceware.zig");

test "generates passphrases of the correct length" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectEqual((try niceware.generatePassphrase(ally, 2)).len, 1);
    try testing.expectEqual((try niceware.generatePassphrase(ally, 20)).len, 10);
    try testing.expectEqual((try niceware.generatePassphrase(ally, 512)).len, 256);
}

test "errors when generating passphrase with an odd number of bytes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectError(error.OddSize, niceware.generatePassphrase(ally, 3));
    try testing.expectError(error.OddSize, niceware.generatePassphrase(ally, 23));
}

test "errors when generating passphrases that are too large" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectError(error.SizeTooLarge, niceware.generatePassphrase(ally, 1026));
}

test "errors when generating passphrases that are too small" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectError(error.SizeTooSmall, niceware.generatePassphrase(ally, 1));
}

test "errors when byte array has odd length" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectError(error.OddSize, niceware.bytesToPassphrase(ally, &[_]u8{0} ** 3));
}

test "bytes to passphrase expected" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{"a"},
        try niceware.bytesToPassphrase(ally, &[_]u8{0} ** 2),
    );
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{"zyzzyva"},
        try niceware.bytesToPassphrase(ally, &[_]u8{0xff} ** 2),
    );
    try testing.expectEqualSlices(
        []const u8,
        &[_][]const u8{ "a", "bioengineering", "balloted", "gobbledegook", "creneled", "written", "depriving", "zyzzyva" },
        try niceware.bytesToPassphrase(
            ally,
            &[_]u8{ 0x00, 0x00, 0x11, 0xd4, 0x0c, 0x8c, 0x5a, 0xf7, 0x2e, 0x53, 0xfe, 0x3c, 0x36, 0xa9, 0xff, 0xff },
        ),
    );
}

test "errors when input is not in the wordlist" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectError(
        error.WordNotFound,
        niceware.passphraseToBytes(ally, &[_][]const u8{ "You", "love", "ninetails" }),
    );
}

test "returns expected bytes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const ally = &arena.allocator;
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x00 },
        try niceware.passphraseToBytes(ally, &[_][]const u8{"A"}),
    );
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0xff, 0xff },
        try niceware.passphraseToBytes(ally, &[_][]const u8{"zyzzyva"}),
    );
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x00, 0x11, 0xd4, 0x0c, 0x8c, 0x5a, 0xf7, 0x2e, 0x53, 0xfe, 0x3c, 0x36, 0xa9, 0xff, 0xff },
        try niceware.passphraseToBytes(
            ally,
            &[_][]const u8{ "a", "bioengineering", "balloted", "gobbledegook", "creneled", "written", "depriving", "zyzzyva" },
        ),
    );
}
