const std = @import("std");
const uz = @import("uWebZockets");

const dataset = @import("../shared/dataset.zig");

pub const PATH = "/json/:count";

const body_max = 16 * 1024;
const gzip_level = 9;

const ResponseItem = struct {
    id: i64,
    name: []const u8,
    category: []const u8,
    price: i64,
    quantity: i64,
    active: bool,
    tags: []const []const u8,
    rating: dataset.Rating,
    total: i64,
};

const Body = struct {
    items: []const ResponseItem,
    count: usize,
};

threadlocal var items_buffer: [50]ResponseItem = undefined;

pub fn handle(req: *uz.Request, res: *uz.Response) void {
    const rows = dataset.items() orelse return status(res, "503 Service Unavailable");

    const count_text = req.get_param("count") orelse return status(res, "400 Bad Request");
    const count = std.fmt.parseInt(usize, count_text, 10) catch return status(res, "400 Bad Request");
    if (count < 1 or count > rows.len or count > items_buffer.len) return status(res, "400 Bad Request");

    const params = req.query_params() catch return status(res, "400 Bad Request");
    const multiplier = (params.get_int(u32, "m") catch 1) orelse 1;

    var rendered_buffer: [body_max]u8 = undefined;
    const rendered = std.fmt.bufPrint(
        &rendered_buffer,
        "{f}",
        .{std.json.fmt(render(rows, count, multiplier), .{})},
    ) catch return status(res, "500 Internal Server Error");

    if (req.header_has_token("accept-encoding", "gzip")) {
        var input: [body_max]u8 = undefined;
        var output: [body_max]u8 = undefined;
        const compressed = gzip(rendered, &input, &output) catch
            return status(res, "500 Internal Server Error");

        res.end_with_headers(
            "200 OK",
            "Content-Type: application/json; charset=utf-8\r\nContent-Encoding: gzip\r\n",
            compressed,
        ) catch {};
        return;
    }

    res.end_with_headers("200 OK", "Content-Type: application/json; charset=utf-8\r\n", rendered) catch {};
}

fn render(rows: []const dataset.Item, count: usize, multiplier: u32) Body {
    for (rows[0..count], 0..) |row, index| {
        items_buffer[index] = .{
            .id = row.id,
            .name = row.name,
            .category = row.category,
            .price = row.price,
            .quantity = row.quantity,
            .active = row.active,
            .tags = row.tags,
            .rating = row.rating,
            .total = row.price * row.quantity * @as(i64, @intCast(multiplier)),
        };
    }
    return .{ .items = items_buffer[0..count], .count = count };
}

fn gzip(body: []const u8, input: []u8, output: []u8) ![]const u8 {
    var stream = try uz.compression_stream.CompressionStream.init(.gzip, gzip_level, input);
    defer stream.deinit();

    try stream.write(body);
    if (stream.output_bound() > output.len) return error.BufferTooSmall;
    return stream.finish(output);
}

fn status(res: *uz.Response, text: []const u8) void {
    res.end(text, "") catch {};
}
