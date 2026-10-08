const std = @import("std");
const uz = @import("uWebZockets");

const dataset = @import("shared/dataset.zig");
const paths = @import("shared/paths.zig");

const baseline = @import("handlers/baseline.zig");
const json = @import("handlers/json.zig");
const pipeline = @import("handlers/pipeline.zig");
const ws = @import("handlers/ws.zig");

const Port = struct {
    const h1 = 8080;
    const h1_tls = 8081;
    const h2c = 8082;
    const h2_h3 = 8443;
};

fn routes(app: anytype) !void {
    _ = try app.get(baseline.PATH, baseline.get);
    _ = try app.post(baseline.PATH, baseline.post);
    _ = try app.get(baseline.H2_PATH, baseline.h2);
    _ = try app.get(pipeline.PATH, pipeline.handle);
    _ = try app.get(json.PATH, json.handle);
    _ = try app.ws(ws.PATH, .{ .message = ws.onMessage });
}

fn httpConfig(comptime connections: usize) uz.ServerConfig {
    var config = uz.ServerConfig{};
    config.max_connections = connections;
    config.max_request_line_size = 1024;
    config.max_header_size = 4096;
    config.max_body_size = 2048;
    config.write_queue_size = 16 * 1024;
    config.max_h2_header_block_size = 2048;
    config.max_h2_body_size = 512;
    config.max_h2_response_header_size = 1024;
    config.max_h2_response_header_count = 24;
    return config;
}

fn h2cConfig(comptime connections: usize) uz.ServerConfig {
    var config = httpConfig(connections);
    config.max_h2_header_block_size = 4096;
    config.max_h2_body_size = 16 * 1024;
    config.max_h2_response_header_size = 2048;
    config.max_h2_response_header_count = 32;
    return config;
}

fn runCluster(init: std.process.Init, comptime config: uz.ServerConfig, comptime workers: usize, port: u16) !void {
    var group = try uz.Server.preset(init.io, config).build_cluster(
        std.heap.page_allocator,
        workers,
        .{},
    );
    defer group.deinit();

    const Cluster = @TypeOf(group);
    try group.configure(struct {
        fn call(worker: *Cluster.Worker, _: usize) !void {
            try routes(worker);
        }
    }.call);

    try group.catch_shutdown_signals();
    try group.listen("0.0.0.0", port);
    try group.run();
}

fn httpMode(init: std.process.Init) !void {
    const cpus = std.Thread.getCpuCount() catch 8;
    if (cpus >= 64) return runCluster(init, httpConfig(768), 32, Port.h1);
    if (cpus >= 32) return runCluster(init, httpConfig(1280), 16, Port.h1);
    if (cpus >= 16) return runCluster(init, httpConfig(2560), 8, Port.h1);
    return runCluster(init, httpConfig(5120), 4, Port.h1);
}

fn h2cMode(init: std.process.Init) !void {
    const cpus = std.Thread.getCpuCount() catch 8;
    if (cpus >= 64) return runCluster(init, h2cConfig(256), 32, Port.h2c);
    if (cpus >= 32) return runCluster(init, h2cConfig(512), 16, Port.h2c);
    if (cpus >= 16) return runCluster(init, h2cConfig(1024), 8, Port.h2c);
    return runCluster(init, h2cConfig(2048), 4, Port.h2c);
}

fn tlsMode(init: std.process.Init) !void {
    var app = try uz.App(5120).init_https(
        init.io,
        try nullTerminated(init, paths.certificate(init)),
        try nullTerminated(init, paths.privateKey(init)),
    );
    defer app.deinit();

    try routes(&app);
    try app.catch_shutdown_signals();
    try app.listen("0.0.0.0", Port.h1_tls);
    try app.run();
}

fn h3Mode(init: std.process.Init) !void {
    var app = try uz.App(1280).init_http3(
        init.io,
        try nullTerminated(init, paths.certificate(init)),
        try nullTerminated(init, paths.privateKey(init)),
    );
    defer app.deinit();

    try routes(&app);
    try app.catch_shutdown_signals();
    try app.listen("0.0.0.0", Port.h2_h3);
    try app.listen_udp("0.0.0.0", Port.h2_h3);
    try app.run();
}

fn nullTerminated(init: std.process.Init, value: []const u8) ![:0]u8 {
    const buffer = try init.gpa.allocSentinel(u8, value.len, 0);
    @memcpy(buffer, value);
    return buffer;
}

pub fn main(init: std.process.Init) !void {
    dataset.load(init.io, std.heap.page_allocator, paths.dataset(init));

    const mode = init.environ_map.get("UZ_MODE") orelse "http";
    if (std.mem.eql(u8, mode, "http")) return httpMode(init);
    if (std.mem.eql(u8, mode, "h2c")) return h2cMode(init);
    if (std.mem.eql(u8, mode, "tls")) return tlsMode(init);
    if (std.mem.eql(u8, mode, "h3")) return h3Mode(init);

    std.log.err("unknown UZ_MODE '{s}'", .{mode});
    return error.UnknownMode;
}
