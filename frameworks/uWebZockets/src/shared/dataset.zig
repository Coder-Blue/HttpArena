const std = @import("std");

pub const Rating = struct {
    score: i64,
    count: i64,
};

pub const Item = struct {
    id: i64,
    name: []const u8,
    category: []const u8,
    price: i64,
    quantity: i64,
    active: bool,
    tags: []const []const u8,
    rating: Rating,
};

const FILE_MAX = 4 * 1024 * 1024;

var raw: []u8 = &.{};
var parsed: ?std.json.Parsed([]const Item) = null;

pub fn load(io: std.Io, allocator: std.mem.Allocator, path: []const u8) void {
    raw = readFile(io, allocator, path) catch return;
    parsed = std.json.parseFromSlice([]const Item, allocator, raw, .{}) catch return;
}

pub fn items() ?[]const Item {
    if (parsed) |*value| return value.value;
    return null;
}

fn readFile(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{ .allow_directory = false });
    defer file.close(io);

    const stat = try file.stat(io);
    if (stat.size == 0 or stat.size > FILE_MAX) return error.BadDatasetSize;

    const buffer = try allocator.alloc(u8, @intCast(stat.size));
    const read = try file.readPositionalAll(io, buffer, 0);
    if (read != buffer.len) return error.UnexpectedEndOfFile;
    return buffer;
}
