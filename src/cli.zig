const std = @import("std");
const mem = std.mem;

const default_flags =
    \\Flags:
    \\  -h, --help    Print this message
    \\  -v, --version Print version information
    \\
;

/// A function that runs when the command is present.
pub const ExecuteFn = fn (app: *const App, cmd: Command, args: []const []const u8) void;

pub const Command = struct {
    /// Name of the command.
    name: []const u8,
    /// Usage of the command.
    usage: []const u8,
    /// Description of the command. (Also known as the help message)
    description: []const u8,
    /// Function that runs when this command is present.
    execute: ExecuteFn,
};

pub const App = struct {
    /// Allocator used.
    ally: *mem.Allocator,
    /// Name of the application.
    name: []const u8,
    /// Description of the application.
    description: []const u8,
    /// Version of the application. This usually uses semantic-versioning, but you can use whatever you like.
    version: []const u8,
    /// All commands at top-level.
    commands: std.ArrayList(Command),
    /// Generated help message.
    help: ?[]const u8,
    ready: bool,

    pub const Error = error{
        /// Tried to change state after calling [setup].
        AlreadySetup,
        /// You cannot call [parse] before calling [setup].
        MustSetup,
    } || mem.Allocator.Error;

    pub fn init(
        ally: *mem.Allocator,
        name: []const u8,
        description: []const u8,
        version: []const u8,
    ) App {
        return .{
            .ally = ally,
            .name = name,
            .description = description,
            .version = version,
            .commands = std.ArrayList(Command).init(ally),
            .help = null,
            .ready = false,
        };
    }

    pub fn deinit(self: App) void {
        self.commands.deinit();
        if (self.help) |help| {
            self.ally.free(help);
        }
    }

    /// Add a command.
    pub fn addCommand(self: *App, cmd: Command) !void {
        if (self.ready) return error.AlreadySetup;
        try self.commands.append(cmd);
    }

    pub fn setup(self: *App) !void {
        if (self.ready) return error.AlreadySetup;
        self.ready = true;

        var buf = std.ArrayList(u8).init(self.ally);
        const writer = buf.writer();

        try writer.print("Usage: {s} [flags] [commands]\n", .{self.name});
        try writer.print("\n{s}\n", .{self.description});

        // TODO(bms): this will indent weirdly on really long command names
        try writer.writeAll("\nCommands:\n");
        for (self.commands.items) |cmd| {
            // each one is indented by 2
            try writer.print("  {s}\t\t{s}\n", .{ cmd.name, cmd.description });
        }
        try writer.writeByte('\n');

        try writer.writeAll(default_flags);

        self.help = buf.toOwnedSlice();
    }

    /// Writes the help messaage to 
    pub fn print_help(self: App, writer: anytype) void {
        if (self.help) |help| {
            writer.writeAll(help) catch unreachable;
        } else {
            std.debug.panic("missing help", .{});
        }
    }

    /// Parse [args] and execute commands accordingly.
    /// Note: this expects the program name to be the first argument
    pub fn parse(self: *const App, args: []const []const u8) !void {
        if (!self.ready) return error.MustSetup;

        // TODO(bms): make i/o configurable
        const stdout = std.io.getStdOut().writer();
        const stderr = std.io.getStdErr().writer();

        if (args.len == 1) {
            self.print_help(stdout);
        } else {
            var cmd_found = false;
            // starting at 1 to skip program name
            for (args[1..]) |arg| {
                // look at help and version flags first
                if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "help")) {
                    self.print_help(stdout);
                } else if (mem.eql(u8, arg, "--version") or mem.eql(u8, arg, "-v")) {
                    try stdout.print("Version: {s}\n", .{self.version});
                } else {
                    for (self.commands.items) |cmd| {
                        if (mem.eql(u8, arg, cmd.name)) {
                            cmd.execute(self, cmd, args[2..]);
                            cmd_found = true;
                        }
                    }
                }
            }

            if (!cmd_found and args.len >= 2) {
                try stderr.print("unknown command: {s}\n", .{args[1]});
            }
        }
    }
};

fn testRun(app: *const App, cmd: Command, args: []const []const u8) void {
    _ = app;
    _ = cmd;
    _ = args;
    std.log.crit("running test", .{});
}

test "App" {
    const t = std.testing;

    var app = App.init(
        t.allocator,
        "test",
        "A test application.",
        "0.0.0",
    );
    defer app.deinit();

    try app.addCommand(.{
        .name = "test",
        .usage = "<name>",
        .description = "Run a test by name",
        .execute = testRun,
    });

    try app.setup();
    try app.parse(&[_][]const u8{
        "test", "thing",
    });

    try app.parse(&[_][]const u8{
        "--help",
    });

    const stdout = std.io.getStdOut().writer();
    app.print_help(stdout);
}
