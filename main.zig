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

const reset = "\x1b[0m";

pub fn main() !void {
    var row_buf: [16]u8 = undefined;

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout: *std.io.Writer = &stdout_writer.interface;

    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    const stdin: *std.io.Reader = &stdin_reader.interface;
    var buffer_alignment: usize = 0;
    var space_alignment: usize = 0;
    var row_alignment: usize = 0;

    while (stdin.takeByte()) |b| {
        if (row_alignment == 0) {
            try stdout.print("{x:0>8}: ", .{buffer_alignment});
        }

        try stdout.print("{s}{x:0>2}", .{ getColorForHex(b), b });
        if (b >= ' ' and b <= '~') {
            row_buf[row_alignment] = b;
        } else {
            row_buf[row_alignment] = '.';
        }

        space_alignment += 1;
        row_alignment += 1;
        buffer_alignment += 1;
        if (row_alignment == 16) {
            try stdout.print("  {s}{s}\n", .{ reset, row_buf });
            space_alignment = 0;
            row_alignment = 0;
        } else if (space_alignment == 2) {
            try stdout.print(" ", .{});
            space_alignment = 0;
        } else {}
    } else |err| switch (err) {
        error.EndOfStream => {
            const spaces_array = " " ** 40;
            const missing_bytes = (16 - row_alignment) % 16;
            const missing_spaces = missing_bytes / 2;
            if (missing_bytes > 0 or row_alignment > 0) {
                try stdout.print("{s} {s}{s}\n", .{ spaces_array[0 .. missing_bytes * 2 + missing_spaces], reset, row_buf[0..row_alignment] });
            }
        },
        else => {},
    }

    try stdout.print("\n", .{});
    try stdout.flush();
}
