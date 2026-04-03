const std = @import("std");

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

        try stdout.print("{x:0>2}", .{b});
        if (b >= ' ' and b <= '~') {
            row_buf[row_alignment] = b;
        } else {
            row_buf[row_alignment] = '.';
        }

        space_alignment += 1;
        row_alignment += 1;
        buffer_alignment += 1;
        if (row_alignment == 16) {
            try stdout.print("  {s}\n", .{row_buf});
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
                try stdout.print("{s} {s}\n", .{ spaces_array[0 .. missing_bytes * 2 + missing_spaces], row_buf[0..row_alignment] });
            }
        },
        else => {},
    }

    try stdout.print("\n", .{});
    try stdout.flush();
}
