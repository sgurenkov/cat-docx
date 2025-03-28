const std = @import("std");
const deflate = @import("deflate.zig");
const lib = @import("zip_ls.zig");
const clap = @import("clap");
const print = std.debug.print;

fn readFromFile(allocator: std.mem.Allocator, filePath: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();

    return try file.readToEndAlloc(allocator, 25 * 1024 * 1024);
}

fn readNumber(comptime T: type) !T {
    var buf: [8]u8 = undefined;
    if (try std.io.getStdIn().reader().readUntilDelimiterOrEof(buf[0..], '\n')) |input| {
        return try std.fmt.parseInt(u8, input, 10);
    } else return 0;
}

fn printRecords(records: []lib.Record, writer: anytype) !void {
    for (records, 0..records.len) |rec, i| {
        try std.fmt.format(writer, "{d: >2}. [{d: >8}] {s}\n", .{ i + 1, rec.info.size_u, rec.file_name });
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\ -i, --index <INT>     File index.
        \\<FILE>                 DOCX file path.
    );
    const Output = enum { raw, html, header };
    const parsers = comptime .{
        .FILE = clap.parsers.string,
        .INT = clap.parsers.int(u32, 10),
        .FORMAT = clap.parsers.enumeration(Output),
    };
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    };
    defer res.deinit();
    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    if (res.positionals.len == 0) {
        _ = try std.io.getStdErr().writer().write("No file provided\n");
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }
    const filePath = res.positionals[0];
    const docxFileContent = try readFromFile(arena.allocator(), filePath);

    const file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();
    var stream = std.io.fixedBufferStream(docxFileContent);
    const recs = try lib.centralDirectory(arena.allocator(), stream);

    const out = std.io.getStdOut().writer();
    if (res.args.index) |i| {
        const record = recs[i - 1];
        const content = try lib.inflateBuffer(arena.allocator(), docxFileContent[record.info.offset..]);
        _ = try out.write(content);
    } else {
        try printRecords(recs, out);
    }
}

test {
    std.testing.refAllDecls(@This());
}
