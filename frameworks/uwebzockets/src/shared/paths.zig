const std = @import("std");

pub fn dataset(init: std.process.Init) []const u8 {
    return init.environ_map.get("UZ_DATASET") orelse "/data/dataset.json";
}

pub fn certificate(init: std.process.Init) []const u8 {
    return init.environ_map.get("UZ_CERT") orelse "/certs/server.crt";
}

pub fn privateKey(init: std.process.Init) []const u8 {
    return init.environ_map.get("UZ_KEY") orelse "/certs/server.key";
}
