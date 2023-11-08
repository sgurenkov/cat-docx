const std = @import("std");
const adf = @import("adf.zig");

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

export fn getHeader(ptr: [*]u8, len: usize) u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const aa = arena.allocator();
    defer arena.deinit();

    var header = adf.decodeHeader(ptr[0..len]);
    var list = std.ArrayList(u8).init(aa);

    std.json.stringify(header, .{ .whitespace = .indent_tab }, list.writer()) catch {
        return RES.err.toInt();
    };
    on_result(list.items.ptr, list.items.len);
    return RES.ok.toInt();
}

export fn toHtml(ptr: [*]u8, len: usize) u8 {
    const res = toHtml_(ptr, len) catch |err| switch (err) {
        error.OutOfMemory => return RES.outOfMemory.toInt(),
        else => return RES.err.toInt(),
    };
    on_result(res.items.ptr, res.items.len);
    return RES.ok.toInt();
}

export fn toJson(ptr: [*]u8, len: usize) u8 {
    const res = toJson_(ptr, len) catch |err| switch (err) {
        error.OutOfMemory => return RES.outOfMemory.toInt(),
        else => return RES.err.toInt(),
    };
    on_result(res.ptr, res.len);
    return RES.ok.toInt();
}

fn toJson_(ptr: [*]u8, len: usize) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const aa = arena.allocator();
    defer arena.deinit();

    var header = adf.decodeHeader(ptr[0..len]);
    var deflated_json = ptr[header.documentOffset .. header.documentOffset + len];
    return try adf.inflateBuffer(aa, deflated_json);
}

fn toHtml_(ptr: [*]u8, len: usize) !std.ArrayList(u8) {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const aa = arena.allocator();
    defer arena.deinit();

    var list = std.ArrayList(u8).init(aa);
    var header = adf.decodeHeader(ptr[0..len]);
    var deflated_json = ptr[header.documentOffset .. header.documentOffset + len];
    var inflated_json = try adf.inflateBuffer(aa, deflated_json);
    try adf.adfToHtml(aa, inflated_json, list.writer());
    return list;
}
