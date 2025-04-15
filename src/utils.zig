const std = @import("std");
const c = @cImport({
    @cInclude("pico.h");
    @cInclude("stdio.h");
    @cInclude("pico/stdlib.h");
});

pub fn toSentinel(text: []const u8, allocator: std.mem.Allocator, sentinel: ?u8) ![]const u8 {
    const sentinel_text = try allocator.alloc(u8, text.len + 1);

    for (0..text.len) |i| {
        sentinel_text[i] = text[i];
    }
    sentinel_text[sentinel_text.len - 1] = sentinel orelse 0;
    return sentinel_text;
}

pub fn print(text: []const u8) void {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const c_text = allocator.alloc(u8, text.len + 1) catch unreachable;
    allocator.free(c_text);

    for (0..text.len) |i| {
        c_text[i] = text[i];
    }
    c_text[c_text.len - 1] = 0;

    _ = c.printf(c_text.ptr);
    _ = c.printf("\r\n");
}

pub fn print_i8(number: i8) void {
    var buf: [10]u8 = undefined;
    const data = std.fmt.bufPrint(&buf, "{d}\x00", .{number}) catch unreachable;
    _ = c.printf(data.ptr);
    _ = c.printf("\r\n");
}

pub fn print_u8_nocr(number: u8) void {
    var buf: [10]u8 = undefined;
    const data = std.fmt.bufPrint(&buf, "{d} \x00", .{number}) catch unreachable;
    _ = c.printf(data.ptr);
}

pub fn print_newline() void {
    _ = c.printf("\r\n");
}
