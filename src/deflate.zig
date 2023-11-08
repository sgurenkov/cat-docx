const std = @import("std");
const io = std.io;
const fs = std.fs;
const testing = std.testing;
const mem = std.mem;
const deflate = std.compress.deflate;

pub fn DecompressStream(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error = ReaderType.Error ||
            deflate.Decompressor(ReaderType).Error ||
            error{ WrongChecksum, Unsupported };
        pub const Reader = io.Reader(*Self, Error, read);

        allocator: mem.Allocator,
        inflater: deflate.Decompressor(ReaderType),
        in_reader: ReaderType,
        hasher: std.hash.Adler32,

        fn init(allocator: mem.Allocator, source: ReaderType) !Self {
            return Self{
                .allocator = allocator,
                .inflater = try deflate.decompressor(allocator, source, null),
                .in_reader = source,
                .hasher = std.hash.Adler32.init(),
            };
        }

        pub fn deinit(self: *Self) void {
            self.inflater.deinit();
        }

        // Implements the io.Reader interface
        pub fn read(self: *Self, buffer: []u8) Error!usize {
            if (buffer.len == 0)
                return 0;

            // Read from the compressed stream and update the computed checksum
            const r = try self.inflater.read(buffer);
            if (r != 0) {
                self.hasher.update(buffer[0..r]);
                return r;
            }

            // We've reached the end of stream, check if the checksum matches
            const hash = try self.in_reader.readIntBig(u32);
            if (hash != self.hasher.final())
                return error.WrongChecksum;

            return 0;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn inflate(allocator: mem.Allocator, data: []const u8) ![]u8 {
    var stream = std.io.fixedBufferStream(data);
    var reader = stream.reader();
    var imf = try deflate.decompressor(allocator, reader, null);
    // var inflatedStream = try DecompressStream(@TypeOf(reader)).init(allocator, reader);
    // defer inflatedStream.deinit();
    defer imf.deinit();
    return imf.reader().readAllAlloc(allocator, std.math.maxInt(usize));
}
