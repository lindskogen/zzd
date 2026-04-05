const std = @import("std");

fn printColorEscape(comptime str: *const [7:0]u8) []const u8 {
    const r = std.fmt.parseInt(u8, str[1..3], 16) catch unreachable;
    const g = std.fmt.parseInt(u8, str[3..5], 16) catch unreachable;
    const b = std.fmt.parseInt(u8, str[5..7], 16) catch unreachable;

    return std.fmt.comptimePrint("\x1b[38;2;{d};{d};{d}m", .{ r, g, b });
}

const Colors = .{ .c00 = printColorEscape("#9F9F9F"), .c0x = printColorEscape("#FF77A9"), .c1x = printColorEscape("#FF7777"), .c2x = printColorEscape("#FF852F"), .c3x = printColorEscape("#F89100"), .c4x = printColorEscape("#EC9B00"), .c5x = printColorEscape("#C3B100"), .c6x = printColorEscape("#87C335"), .c7x = printColorEscape("#63C858"), .c8x = printColorEscape("#41CC6C"), .c9x = printColorEscape("#00CF8D"), .cAx = printColorEscape("#00D0BB"), .cBx = printColorEscape("#00CAE9"), .cCx = printColorEscape("#00BEFF"), .cDx = printColorEscape("#53AFFF"), .cEx = printColorEscape("#B794FF"), .cFx = printColorEscape("#E97FE6"), .cFF = printColorEscape("#FFFFFF") };

const nbr_colors = [_][]const u8{ Colors.c0x, Colors.c1x, Colors.c2x, Colors.c3x, Colors.c4x, Colors.c5x, Colors.c6x, Colors.c7x, Colors.c8x, Colors.c9x, Colors.cAx, Colors.cBx, Colors.cCx, Colors.cDx, Colors.cEx, Colors.cFx };

fn getColorForHex(v: u8) []const u8 {
    return switch (v) {
        0x00 => Colors.c00,
        0xff => Colors.cFF,
        else => nbr_colors[v >> 4],
    };
}

fn getColorForHexInverted(v: u8) []const u8 {
    return switch (v) {
        0x00 => Colors.c00,
        0xff => Colors.cFF,
        else => nbr_colors[v & 0x0F],
    };
}

const reset = "\x1b[0m";

const color_hex_lut = blk: {
    @setEvalBranchQuota(100_000);
    var table: [256][]const u8 = undefined;
    for (0..256) |i| {
        const b: u8 = @intCast(i);
        const color = getColorForHex(b);
        table[i] = color ++ std.fmt.comptimePrint("{x:0>2}", .{b});
    }
    break :blk table;
};

const inverted_color_hex_lut = blk: {
    @setEvalBranchQuota(100_000);
    var table: [256][]const u8 = undefined;
    for (0..256) |i| {
        const b: u8 = @intCast(i);
        const color = getColorForHexInverted(b);
        table[i] = color ++ std.fmt.comptimePrint("{x:0>2}", .{b});
    }
    break :blk table;
};

const plain_hex_lut = blk: {
    @setEvalBranchQuota(100_000);
    var table: [256][]const u8 = undefined;
    for (0..256) |i| {
        const b: u8 = @intCast(i);
        table[i] = std.fmt.comptimePrint("{x:0>2}", .{b});
    }
    break :blk table;
};

pub fn main() !void {
    var stdout_buf: [8 * 1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout: *std.io.Writer = &stdout_writer.interface;

    var read_buf: [64 * 1024]u8 = undefined;
    var input_is_stdin = false;
    var inverted = false;

    var arg_idx: usize = 1;
    while (arg_idx < std.os.argv.len) : (arg_idx += 1) {
        const arg: [:0]const u8 = std.mem.span(std.os.argv[arg_idx]);
        if (std.mem.eql(u8, arg, "-i")) {
            inverted = true;
        } else {
            break;
        }
    }

    const file_or_stdin = blk: {
        if (arg_idx < std.os.argv.len) {
            const path_null_terminated: [*:0]u8 = std.os.argv[arg_idx];
            const path: [:0]const u8 = std.mem.span(path_null_terminated);

            const f = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |e| switch (e) {
                error.AccessDenied => {
                    try stdout.print("Not allowed to read file: {s}\n", .{path});
                    try stdout.flush();
                    std.process.exit(1);
                },
                error.FileNotFound => {
                    try stdout.print("File not found: {s}\n", .{path});
                    try stdout.flush();
                    std.process.exit(1);
                },
                else => {
                    try stdout.print("Failed to read: {s} reason: {s}\n", .{ path, @errorName(e) });
                    try stdout.flush();
                    std.process.exit(1);
                },
            };

            break :blk f;
        } else {
            input_is_stdin = true;
            break :blk std.fs.File.stdin();
        }
    };

    const no_color = std.posix.getenv("NO_COLOR") != null or
        !std.posix.isatty(std.posix.STDOUT_FILENO);

    var stdin_reader = file_or_stdin.reader(&read_buf);

    const stdin: *std.io.Reader = &stdin_reader.interface;

    run_loop(no_color, inverted, input_is_stdin, stdin, stdout) catch |err| switch (err) {
        error.WriteFailed => {},
    };
}

fn run_loop(no_color: bool, inverted: bool, streaming: bool, stdin: *std.io.Reader, stdout: *std.io.Writer) !void {
    const hex_lut = if (no_color) &plain_hex_lut else if (inverted) &inverted_color_hex_lut else &color_hex_lut;
    const line_reset: []const u8 = if (no_color) "" else reset;

    var row_buf: [16]u8 = undefined;
    var buffer_alignment: usize = 0;
    var row_alignment: usize = 0;

    while (stdin.takeByte()) |b| {
        if (row_alignment == 0) {
            try stdout.print("{x:0>8}: ", .{buffer_alignment});
        }

        try stdout.writeAll(hex_lut[b]);
        if (b >= ' ' and b <= '~') {
            row_buf[row_alignment] = b;
        } else {
            row_buf[row_alignment] = '.';
        }

        row_alignment += 1;
        buffer_alignment += 1;
        if (row_alignment == 16) {
            try stdout.print("  {s}{s}\n", .{ line_reset, row_buf });
            if (streaming) {
                try stdout.flush();
            }
            row_alignment = 0;
        } else if (row_alignment % 2 == 0) {
            try stdout.writeAll(" ");
        }
    } else |err| switch (err) {
        error.EndOfStream => {
            const spaces_array = " " ** 40;
            const missing_bytes = (16 - row_alignment) % 16;
            const missing_spaces = missing_bytes / 2;
            if (missing_bytes > 0 or row_alignment > 0) {
                try stdout.print("{s} {s}{s}\n", .{ spaces_array[0 .. missing_bytes * 2 + missing_spaces], line_reset, row_buf[0..row_alignment] });
            }
        },
        else => {
            try stdout.print("Read error: {s}\n", .{@errorName(err)});
        },
    }

    try stdout.flush();
}
