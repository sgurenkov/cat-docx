const std = @import("std");
const deflate = @import("deflate.zig");
const clap = @import("clap");
const print = std.debug.print;

fn readFromFile(allocator: std.mem.Allocator, filePath: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();

    return try file.readToEndAlloc(allocator, 25 * 1024 * 1024);
}

// PKZIP header definitions
// #define LOCSIG 0x04034b50L      /* four-byte lead-in (lsb first) */
// #define LOCFLG 6                /* offset of bit flag */
// #define  CRPFLG 1               /*  bit for encrypted entry */
// #define  EXTFLG 8               /*  bit for extended local header */
// #define LOCHOW 8                /* offset of compression method */
// #define LOCTIM 10               /* file mod time (for decryption) */
// #define LOCCRC 14               /* offset of crc */
// #define LOCSIZ 18               /* offset of compressed size */
// #define LOCLEN 22               /* offset of uncompressed length */
// #define LOCFIL 26               /* offset of file name field length */
// #define LOCEXT 28               /* offset of extra field length */
// #define LOCHDR 30               /* size of local header, including sig */
// #define EXTHDR 16               /* size of extended local header, inc sig */
// #define RAND_HEAD_LEN  12       /* length of encryption random header */

const LOCSIG = 0x04034b50;
const ENC_BIT_FLAG = 1; // bit for encrypted entry
const EXT_HEAD_FLAG = 8; // bit for extended local header
const DEFLATE = 8; // compression method
const LOCH_LEN = 30; // without file name and extra field
//
// in little endian
const LocalFileHeader = packed struct {
    // offset|bytes|description
    // 0      4	Local file header signature = 0x04034b50 (PK♥♦ or "PK\3\4")
    header_signature: u32,
    // 4      2	Version needed to extract (minimum)
    version: u16,
    // 6      2	General purpose bit flag
    bit_flag: u16,
    // 8      2	Compression method; e.g. none = 0, DEFLATE = 8 (or "\0x08\0x00")
    compression_method: u16,
    // 10     2	File last modification time
    modification_time: u16,
    // 12     2	File last modification date
    modification_date: u16,
    // 14     4	CRC-32 of uncompressed data
    crc32_uncompressed: u32,
    // 18     4	Compressed size (or 0xffffffff for ZIP64)
    compressed_size: u32,
    // 22     4	Uncompressed size (or 0xffffffff for ZIP64)
    uncompressed_size: u32,
    // 26     2	File name length (n)
    file_name_length: u16,
    // 28     2	Extra field length (m)
    extra_field_length: u16,
    // 30     n	File name
    // 30+n   m	Extra field
};

fn readHeader(buffer: []u8) !LocalFileHeader {
    var stream = std.io.fixedBufferStream(buffer);
    return try stream.reader().readStruct(LocalFileHeader);
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\<FILE>                   ADF file path
    );
    const Output = enum { raw, html, header };
    const parsers = comptime .{
        .FILE = clap.parsers.string,
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

    const defaultFilePath = "../document.adft";
    const filePath = if (res.positionals.len > 0) res.positionals[0] else defaultFilePath;
    const docxFileContent = try readFromFile(arena.allocator(), filePath);

    const local_header = try readHeader(docxFileContent);
    const content_offset = LOCH_LEN + local_header.file_name_length + local_header.extra_field_length;
    const encrypted = local_header.bit_flag & ENC_BIT_FLAG != 0;
    const ext_header = local_header.bit_flag & EXT_HEAD_FLAG != 0;
    const compressed_content = docxFileContent[content_offset .. content_offset + local_header.compressed_size];
    std.debug.print("deflate: {}\n", .{local_header.compression_method == DEFLATE});
    std.debug.print("encrypted: {}\n", .{encrypted});
    std.debug.print("extended header: {}\n", .{ext_header});
    std.debug.print("content offset: {d}\n", .{content_offset});
    std.debug.print("local header signature: {}\n", .{local_header.header_signature == LOCSIG});

    const content = try deflate.inflate(arena.allocator(), compressed_content);
    std.debug.print("{s}\n", .{content});
}

test {
    @import("std").testing.refAllDecls(@This());
}
