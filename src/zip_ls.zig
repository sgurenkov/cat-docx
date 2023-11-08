const std = @import("std");
const format = std.fmt.format;

pub fn inflateBuffer(allocator: std.mem.Allocator, data: []u8) ![]const u8 {
    var contentStream = std.io.fixedBufferStream(data);

    var gzip_stream = try std.compress.zlib.decompressStream(allocator, contentStream.reader());
    defer gzip_stream.deinit();

    const result = try gzip_stream.reader().readAllAlloc(allocator, std.math.maxInt(usize));

    return result;
}

const CDSIG = 0x02014b50;
const CentralDirectory = struct {
    // 0 	4 	Central directory file header signature = 0x02014b50
    signature: u32,
    // 4 	2 	Version made by
    version_m: u16,
    // 6 	2 	Version needed to extract (minimum)
    version_n: u16,
    // 8 	2 	General purpose bit flag
    flag: u16,
    // 10 	2 	Compression method
    method: u16,
    // 12 	2 	File last modification time
    modified_t: u16,
    // 14 	2 	File last modification date
    modifield_d: u16,
    // 16 	4 	CRC-32 of uncompressed data
    crc32: u32,
    // 20 	4 	Compressed size (or 0xffffffff for ZIP64)
    size_c: u32,
    // 24 	4 	Uncompressed size (or 0xffffffff for ZIP64)
    size_u: u32,
    // 28 	2 	File name length (n)
    file_name_len: u16,
    // 30 	2 	Extra field length (m)
    extra_field_len: u16,
    // 32 	2 	File comment length (k)
    comment_len: u16,
    // 34 	2 	Disk number where file starts (or 0xffff for ZIP64)
    disk_number: u16,
    // 36 	2 	Internal file attributes
    int_attr: u16,
    // 38 	4 	External file attributes
    ext_attrs: u32,
    // 42 	4 	Relative offset of local file header (or 0xffffffff for ZIP64). This is the number of bytes between the start of the first disk on which the file occurs, and the start of the local file header. This allows software reading the central directory to locate the position of the file inside the ZIP file.
    offset: u32,
    // 46 	n 	File name
    file_name: []const u8,
    // 46+n 	m 	Extra field
    extra_field: []const u8,
    // 46+n+m 	k 	File comment
    comment: []const u8,
};

const ECDSIG = 0x06054b50;
const EOFCentralDirectory = packed struct {
    // 0 	4 	End of central directory signature = 0x06054b50
    signature: u32,
    // 4 	2 	Number of this disk (or 0xffff for ZIP64)
    disk: u16,
    // 6 	2 	Disk where central directory starts (or 0xffff for ZIP64)
    start_disk: u16,
    // 8 	2 	Number of central directory records on this disk (or 0xffff for ZIP64)
    records: u16,
    // 10 	2 	Total number of central directory records (or 0xffff for ZIP64)
    total_records: u16,
    // 12 	4 	Size of central directory (bytes) (or 0xffffffff for ZIP64)
    size: u32,
    // 16 	4 	Offset of start of central directory, relative to start of archive (or 0xffffffff for ZIP64)
    offset: u32,
    // 20 	2 	Comment length (n)
    comment_length: u16,
    // 22 	n 	Comment
    // comment: []const u8,
};

pub fn readEofCentralDirectory(buffer: []u8) !?EOFCentralDirectory {
    return for (0..buffer.len - 4) |i| {
        var sig: u32 = std.mem.bytesAsValue(u32, buffer[i .. i + 4]);
        if (std.mem.eql(ECDSIG, sig)) {
            var res: EOFCentralDirectory = undefined;
            _ = res;
            break std.mem.bytesAsValue(EOFCentralDirectory, buffer[i .. i + 22]);
        }
    } else null;
}

test "readEofCentralDirectory" {
    const input = [_]u16{
        0x0400, 0x0014, 0x0000, 0x4b50, 0x0605, 0x0000, 0x0000, 0x0001,
        0x0001, 0x004f, 0x0000, 0x0257, 0x0000, 0x0000,
    };
    std.debug.print("{any}", .{input});
}
