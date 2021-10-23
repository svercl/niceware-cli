const std = @import("std");
const testing = std.testing;
const util = @import("util.zig");

test "isStringNumeric" {
    try std.testing.expect(util.isStringNumeric("123"));
    try std.testing.expect(util.isStringNumeric("0123"));
}

test "!isStringNumeric" {
    try std.testing.expect(util.isStringNumeric("+123"));
    try std.testing.expect(util.isStringNumeric("numeric"));
}
