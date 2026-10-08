const std = @import("std");
const uz = @import("uWebZockets");

pub const PATH = "/pipeline";

pub fn handle(_: *uz.Request, res: *uz.Response) void {
    res.text("ok") catch {};
}
