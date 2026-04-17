//! zzd — colored xxd-style hex dump.
//!
//! Usage from another Zig project:
//!
//!   const zzd = @import("zzd");
//!
//!   try zzd.dump(buffer, writer, .{});            // from a []const u8
//!   try zzd.dumpReader(reader, writer, .{ .streaming = true }); // from a Reader
//!
//! The caller owns the writer and is responsible for flushing it.

const std = @import("std");
const Io = std.Io;

pub const Options = struct {
    /// When false, no ANSI color escapes are emitted.
    color: bool = true,
    /// When true, color is chosen from the low nibble instead of the high
    /// nibble. Makes identical low-nibble values easy to spot visually.
    inverted: bool = false,
    /// Flush the writer after every 16-byte row. Useful when the input is a
    /// live stream (e.g. stdin) and the caller wants incremental output.
    streaming: bool = false,
};

fn printColorEscape(comptime str: *const [7:0]u8) []const u8 {
    const r = std.fmt.parseInt(u8, str[1..3], 16) catch unreachable;
    const g = std.fmt.parseInt(u8, str[3..5], 16) catch unreachable;
    const b = std.fmt.parseInt(u8, str[5..7], 16) catch unreachable;
    return std.fmt.comptimePrint("\x1b[38;2;{d};{d};{d}m", .{ r, g, b });
}

const Colors = .{
    .c00 = printColorEscape("#9F9F9F"),
    .c0x = printColorEscape("#FF77A9"),
    .c1x = printColorEscape("#FF7777"),
    .c2x = printColorEscape("#FF852F"),
    .c3x = printColorEscape("#F89100"),
    .c4x = printColorEscape("#EC9B00"),
    .c5x = printColorEscape("#C3B100"),
    .c6x = printColorEscape("#87C335"),
    .c7x = printColorEscape("#63C858"),
    .c8x = printColorEscape("#41CC6C"),
    .c9x = printColorEscape("#00CF8D"),
    .cAx = printColorEscape("#00D0BB"),
    .cBx = printColorEscape("#00CAE9"),
    .cCx = printColorEscape("#00BEFF"),
    .cDx = printColorEscape("#53AFFF"),
    .cEx = printColorEscape("#B794FF"),
    .cFx = printColorEscape("#E97FE6"),
    .cFF = printColorEscape("#FFFFFF"),
};

const nbr_colors = [_][]const u8{
    Colors.c0x, Colors.c1x, Colors.c2x, Colors.c3x,
    Colors.c4x, Colors.c5x, Colors.c6x, Colors.c7x,
    Colors.c8x, Colors.c9x, Colors.cAx, Colors.cBx,
    Colors.cCx, Colors.cDx, Colors.cEx, Colors.cFx,
};

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
        table[i] = getColorForHex(b) ++ std.fmt.comptimePrint("{x:0>2}", .{b});
    }
    break :blk table;
};

const inverted_color_hex_lut = blk: {
    @setEvalBranchQuota(100_000);
    var table: [256][]const u8 = undefined;
    for (0..256) |i| {
        const b: u8 = @intCast(i);
        table[i] = getColorForHexInverted(b) ++ std.fmt.comptimePrint("{x:0>2}", .{b});
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

const Formatter = struct {
    hex_lut: *const [256][]const u8,
    line_reset: []const u8,
    streaming: bool,
    row_buf: [16]u8 = undefined,
    buffer_alignment: usize = 0,
    row_alignment: usize = 0,

    fn init(options: Options) Formatter {
        const hex_lut = if (!options.color)
            &plain_hex_lut
        else if (options.inverted)
            &inverted_color_hex_lut
        else
            &color_hex_lut;
        return .{
            .hex_lut = hex_lut,
            .line_reset = if (options.color) reset else "",
            .streaming = options.streaming,
        };
    }

    fn writeByte(self: *Formatter, writer: *Io.Writer, b: u8) Io.Writer.Error!void {
        if (self.row_alignment == 0) {
            try writer.print("{x:0>8}: ", .{self.buffer_alignment});
        }

        try writer.writeAll(self.hex_lut[b]);
        self.row_buf[self.row_alignment] = if (b >= ' ' and b <= '~') b else '.';

        self.row_alignment += 1;
        self.buffer_alignment += 1;
        if (self.row_alignment == 16) {
            try writer.print("  {s}{s}\n", .{ self.line_reset, self.row_buf });
            if (self.streaming) try writer.flush();
            self.row_alignment = 0;
        } else if (self.row_alignment % 2 == 0) {
            try writer.writeAll(" ");
        }
    }

    fn finish(self: *Formatter, writer: *Io.Writer) Io.Writer.Error!void {
        if (self.row_alignment == 0) return;
        const spaces_array = " " ** 40;
        const missing_bytes = 16 - self.row_alignment;
        const missing_spaces = missing_bytes / 2;
        try writer.print("{s} {s}{s}\n", .{
            spaces_array[0 .. missing_bytes * 2 + missing_spaces],
            self.line_reset,
            self.row_buf[0..self.row_alignment],
        });
    }
};

/// Dump `buffer` as a colored xxd-style hex dump to `writer`.
/// Does not flush the writer; the caller is responsible for that.
pub fn dump(buffer: []const u8, writer: *Io.Writer, options: Options) Io.Writer.Error!void {
    var formatter: Formatter = .init(options);
    for (buffer) |b| try formatter.writeByte(writer, b);
    try formatter.finish(writer);
}

/// Stream bytes from `reader` and dump them to `writer`. Reads until
/// `error.EndOfStream`; any other reader error is returned.
pub fn dumpReader(reader: *Io.Reader, writer: *Io.Writer, options: Options) !void {
    var formatter: Formatter = .init(options);
    while (reader.takeByte()) |b| {
        try formatter.writeByte(writer, b);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    try formatter.finish(writer);
}

