const std = @import("std");
const Io = std.Io;

const zzd = @import("zzd");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);

    var stdout_buf: [8 * 1024]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &stdout_buf);
    const stdout: *Io.Writer = &stdout_writer.interface;

    var read_buf: [64 * 1024]u8 = undefined;
    var input_is_stdin = false;
    var inverted = false;

    var arg_idx: usize = 1;
    while (arg_idx < args.len) : (arg_idx += 1) {
        if (std.mem.eql(u8, args[arg_idx], "-i")) {
            inverted = true;
        } else {
            break;
        }
    }

    const file_or_stdin = blk: {
        if (arg_idx < args.len) {
            const path = args[arg_idx];
            const f = Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only }) catch |e| switch (e) {
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
            break :blk Io.File.stdin();
        }
    };

    const no_color = init.environ_map.get("NO_COLOR") != null or
        !try Io.File.stdout().isTty(io);

    var stdin_reader = file_or_stdin.reader(io, &read_buf);
    const stdin: *Io.Reader = &stdin_reader.interface;

    zzd.dumpReader(stdin, stdout, .{
        .color = !no_color,
        .inverted = inverted,
        .streaming = input_is_stdin,
    }) catch |err| switch (err) {
        error.WriteFailed => {},
        else => {
            try stdout.print("Read error: {s}\n", .{@errorName(err)});
        },
    };

    try stdout.flush();
}
