const std = @import("std");
const uz = @import("uWebZockets");

pub const PATH = "/baseline11";
pub const H2_PATH = "/baseline2";

pub fn get(req: *uz.Request, res: *uz.Response) void {
    respond(req, res, false);
}

pub fn post(req: *uz.Request, res: *uz.Response) void {
    respond(req, res, true);
}

pub fn h2(req: *uz.Request, res: *uz.Response) void {
    respond(req, res, false);
}

fn respond(req: *uz.Request, res: *uz.Response, with_body: bool) void {
    var sum = sumQuery(req);
    if (with_body) sum += parseIntLoose(req.text());

    var buffer: [24]u8 = undefined;
    const body = std.fmt.bufPrint(&buffer, "{d}", .{sum}) catch return;
    res.text(body) catch {};
}

fn sumQuery(req: *uz.Request) i64 {
    const params = req.query_params() catch return 0;
    var sum: i64 = 0;
    var iterator = params.pairs();
    while (iterator.next()) |pair| {
        sum += std.fmt.parseInt(i64, pair.value, 10) catch 0;
    }
    return sum;
}

fn parseIntLoose(text: []const u8) i64 {
    var index: usize = 0;
    while (index < text.len and (text[index] == ' ' or text[index] == '\r' or text[index] == '\n')) index += 1;

    var negative = false;
    if (index < text.len and text[index] == '-') {
        negative = true;
        index += 1;
    }

    var value: i64 = 0;
    while (index < text.len and text[index] >= '0' and text[index] <= '9') : (index += 1) {
        value = value * 10 + (text[index] - '0');
    }
    return if (negative) -value else value;
}
