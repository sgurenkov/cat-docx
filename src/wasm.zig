const std = @import("std");
const lib = @import("zip_ls.zig");

extern fn on_result(ptr: [*]const u8, len: usize) void;

const allocator = std.heap.wasm_allocator;

const RES = enum(u8) {
    ok = 0,
    err = 1,
    outOfMemory = 2,
    fn toInt(self: RES) u8 {
        return @intFromEnum(self);
    }
};

export fn listContent(ptr: [*]u8, len: usize) u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const aa = arena.allocator();
    defer arena.deinit();

    // var header = lib.decodeHeader(ptr[0..len]);
    var stream = std.io.fixedBufferStream(ptr[0..len]);
    var cd = lib.centralDirectory(aa, stream) catch {
        return RES.err.toInt();
    };
    var list = std.ArrayList(u8).init(aa);

    std.json.stringify(cd, .{ .whitespace = .indent_tab }, list.writer()) catch {
        return RES.err.toInt();
    };
    on_result(list.items.ptr, list.items.len);
    return RES.ok.toInt();
}

export fn readRecord(ptr: [*]u8, len: usize, index: usize) u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const aa = arena.allocator();
    defer arena.deinit();

    var stream = std.io.fixedBufferStream(ptr[0..len]);
    var cd = lib.centralDirectory(aa, stream) catch {
        return RES.err.toInt();
    };

    const record = cd[index];
    const content = lib.inflateBuffer(arena.allocator(), ptr[record.info.offset..len]) catch {
        return RES.err.toInt();
    };
    on_result(content.ptr, content.len);
    return RES.ok.toInt();
}
