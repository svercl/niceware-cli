const std = @import("std");
const ascii = std.ascii;
const fmt = std.fmt;

/// Determines if [what] is help, -h or --help.
pub fn isStringNumeric(s: []const u8) bool {
    for (s) |c| {
        // if any character is a non-digit, then it's not all digits
        if (!ascii.isDigit(c)) {
            return false;
        }
    }
    return true;
}
