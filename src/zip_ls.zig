const std = @import("std");
const format = std.fmt.format;
const testing = std.testing;
const deflate = @import("deflate.zig");

const ECDSIG: u32 = 0x06054b50;
const ECDLEN = 22;
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

pub fn eofCentralDirectory(stream: anytype) !EOFCentralDirectory {
    var s = stream;
    // seek to the end minus the size of a struct and go backwards afterwards
    try s.seekTo(try s.getEndPos() - ECDLEN);
    var reader = s.reader();

    const found: ?u64 = while (true) : (try s.seekBy(-1)) {
        const sig = try reader.readIntNative(u32);
        if (sig == ECDSIG) {
            break try s.getPos() - 4;
        }
    } else null;

    if (found) |_pos| {
        const pos: usize = @intCast(_pos);
        const ptr: *[@sizeOf(EOFCentralDirectory)]u8 = @ptrCast(s.buffer[pos .. pos + ECDLEN]);
        return std.mem.bytesToValue(EOFCentralDirectory, ptr);
    }
    return error.EOFCentralDirectoryNotFound;
}

test "eofCentralDirectory success" {
    var input = [_]u8{
        0x00, 0x04, 0x14, 0x00, 0x00, 0x00, 0x50, 0x4b, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00,
        0x01, 0x00, 0x4f, 0x00, 0x00, 0x00, 0x57, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    var stream = std.io.fixedBufferStream(input[0..]);
    const ecd = try eofCentralDirectory(stream);
    try testing.expectEqual(ECDSIG, ecd.signature);
    try testing.expectEqual(@as(u32, 599), ecd.offset);
    try testing.expectEqual(@as(u32, 79), ecd.size);
    try testing.expectEqual(@as(u16, 0), ecd.comment_length);
    try testing.expectEqual(@as(u16, 1), ecd.total_records);
}

// test "eofCentralDirectory not_found" {
//     var input = [_]u8{
//         0x00, 0x04, 0x14, 0x00, 0x00, 0x00, 0x50, 0x4c, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00,
//         0x01, 0x00, 0x4f, 0x00, 0x00, 0x00, 0x57, 0x02, 0x00, 0x00, 0x00, 0x00,
//     };
//     var stream = std.io.fixedBufferStream(input[0..]);
//     const ecd = try eofCentralDirectory(stream);
//     try testing.expectError(error.EOFCentralDirectoryNotFound, ecd);
// }

const CDSIG = 0x02014b50;
const CD_REC_LEN = 46;
const CentralDirectory = packed struct {
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
    // file_name: []const u8,
    // 46+n 	m 	Extra field
    // extra_field: []const u8,
    // 46+n+m 	k 	File comment
    // comment: []const u8,
};

pub const Record = struct {
    info: CentralDirectory,
    file_name: []u8,
};

pub fn centralDirectory(allocator: std.mem.Allocator, stream: anytype) ![]Record {
    var s = stream;
    var r = s.reader();
    const ecd = try eofCentralDirectory(s);

    var records = std.ArrayList(Record).init(allocator);
    try s.seekTo(ecd.offset);
    while (records.items.len < ecd.records) {
        const pos: usize = @intCast(try s.getPos());
        var ptr: *[@sizeOf(CentralDirectory)]u8 = @ptrCast(stream.buffer[pos .. pos + CD_REC_LEN]);
        const item = std.mem.bytesToValue(CentralDirectory, ptr);
        try s.seekBy(CD_REC_LEN);
        var file_name: []u8 = try allocator.alloc(u8, item.file_name_len);
        _ = try r.read(file_name);
        try records.append(.{ .info = item, .file_name = file_name });
        try s.seekBy(item.comment_len + item.extra_field_len);
    }
    return records.items;
}

test "centralDirectory" {
    var input = [_]u8{
        0x50, 0x4b, 0x01, 0x02, 0x1e, 0x03, 0x14, 0x00, 0x00, 0x00, 0x08, 0x00, 0x6b, 0xbc, 0x63, 0x57,
        0x39, 0x37, 0xe8, 0x96, 0x14, 0x02, 0x00, 0x00, 0x38, 0x05, 0x00, 0x00, 0x09, 0x00, 0x18, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0xa4, 0x81, 0x00, 0x00, 0x00, 0x00, 0x62, 0x75,
        0x69, 0x6c, 0x64, 0x2e, 0x7a, 0x69, 0x67, 0x55, 0x54, 0x05, 0x00, 0x03, 0xf9, 0xbb, 0x45, 0x65,
        0x75, 0x78, 0x0b, 0x00, 0x01, 0x04, 0xf7, 0x01, 0x00, 0x00, 0x04, 0x14, 0x00, 0x00, 0x00,
    };
    var allocator = std.testing.allocator;
    var fs = std.io.fixedBufferStream(input[0..]);
    const records = try centralDirectory(allocator, fs.reader());
    allocator.free(records);
    try testing.expectEqual(@as(usize, 1), records.len);
}

// Entry
const CompressionMethod = enum(u16) {
    Store = 0,
    Deflate = 8,
    _,
};

const LOCSIG = 0x04034b50;
const ENC_BIT_FLAG = 1; // bit for encrypted entry
const EXT_HEAD_FLAG = 8; // bit for extended local header
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
    compression_method: CompressionMethod,
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

pub fn inflateBuffer(allocator: std.mem.Allocator, data: []u8) ![]const u8 {
    const local_header = try readHeader(data);
    const content_offset = LOCH_LEN + local_header.file_name_length + local_header.extra_field_length;
    const compressed_content = data[content_offset .. content_offset + local_header.compressed_size];
    // const encrypted = local_header.bit_flag & ENC_BIT_FLAG != 0;
    // const ext_header = local_header.bit_flag & EXT_HEAD_FLAG != 0;
    // std.debug.print("method: {d}\n", .{local_header.compression_method});
    // std.debug.print("encrypted: {}\n", .{encrypted});
    // std.debug.print("extended header: {}\n", .{ext_header});
    // std.debug.print("c_size: {d}\n", .{local_header.compressed_size});
    // std.debug.print("u_size: {d}\n", .{local_header.uncompressed_size});

    switch (local_header.compression_method) {
        .Store => return compressed_content,
        .Deflate => return try deflate.inflate(allocator, compressed_content),
        else => return error.Unsupported,
    }
}
