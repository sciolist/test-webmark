const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const os = std.os;
const mem = std.mem;
const Pg = @import("./pg.zig");
const ObjectPool = @import("./object_pool.zig").ObjectPool;
const util = @import("./utils.zig");
const PGPool = ObjectPool(Pg.Client, pgConnect, 0x80, true);
const Stream = util.Stream;
const ArrayList = @import("./array_list.zig").ArrayList;

pub const io_mode = .evented;

const Fortune = struct {
    id: u32,
    message: []const u8
};

var alloc: std.mem.Allocator = std.heap.c_allocator;
var pgpool: PGPool = undefined;

fn pgConnect(allocator: std.mem.Allocator) !*Pg.Client {
    var client = try allocator.create(Pg.Client);
    errdefer allocator.destroy(client);

    client.* = Pg.Client.init(allocator, .{
        .host = "webmarkdb",
        .port = 5432,
        .user = "postgres",
        .password = "thisisntevenused",
        .database = "postgres"
    });

    try client.connect();
    return client;
}

pub fn main() !void {
    pgpool = PGPool.init(alloc);
    defer pgpool.deinit();

    const address = try std.net.Address.parseIp4("0.0.0.0", 3000);
    const sock_flags = os.SOCK.STREAM | os.SOCK.CLOEXEC | os.SOCK.NONBLOCK;
    const proto = if (address.any.family == os.AF.UNIX) @as(u32, 0) else os.IPPROTO.TCP;

    const sockfd = try os.socket(address.any.family, sock_flags, proto);
    errdefer os.closeSocket(sockfd);

    if (@hasDecl(os.TCP, "NODELAY")) {
        try os.setsockopt(sockfd, os.IPPROTO.TCP, os.TCP.NODELAY, mem.asBytes(&@as(usize, @boolToInt(true))));
    }
    if (@hasDecl(os.TCP, "QUICKACK")) {
        try os.setsockopt(sockfd, os.IPPROTO.TCP, os.TCP.QUICKACK, mem.asBytes(&@as(usize, @boolToInt(true))));
    }
    if (@hasDecl(os.SO, "NOSIGPIPE")) {
        try os.setsockopt(sockfd, os.SOL.SOCKET, os.SO.NOSIGPIPE, mem.asBytes(&@as(usize, @boolToInt(true))));
    }
    if (@hasDecl(os.SO, "REUSEPORT")) {
        try os.setsockopt(sockfd, os.SOL.SOCKET, os.SO.REUSEPORT, mem.asBytes(&@as(usize, @boolToInt(true))));
    }
    if (@hasDecl(os.SO, "REUSEADDR")) {
        try os.setsockopt(sockfd, os.SOL.SOCKET, os.SO.REUSEADDR, mem.asBytes(&@as(usize, @boolToInt(true))));
    }

    var socklen = address.getOsSockLen();
    var addr = address;
    try os.bind(sockfd, &address.any, socklen);
    try os.listen(sockfd, 0x40);
    try os.getsockname(sockfd, &addr.any, &socklen);

    var accepted_addr: std.net.Address = undefined;
    var adr_len: os.socklen_t = @sizeOf(std.net.Address);
    var loop = std.event.Loop.instance orelse return error.requires_evloop;
    std.debug.print("listening.\n", .{});
    while (true) {
        const clientfd = try loop.accept(sockfd, &accepted_addr.any, &adr_len, std.os.SOCK.NONBLOCK | std.os.SOCK.CLOEXEC);
        try loop.runDetached(alloc, runClientAsync, .{ clientfd });
    }
}

fn runClientAsync(clientfd: os.socket_t) void {
    handleClient(clientfd) catch |err| switch(err) {
        error.ConnectionResetByPeer,
        error.BrokenPipe,
        error.EndOfStream => {},
        else => {
            std.debug.print("client failed {s}.\n", .{@errorName(err)});
            if (@errorReturnTrace()) |trace| {
                std.debug.dumpStackTrace(trace.*);
            }
        }
    };
}

const HttpContext = struct {
    fd: os.socket_t,
    allocator: std.mem.Allocator,
    method: []const u8,
    url: []const u8,
    body: ArrayList(u8).Writer
};

fn handleClient(clientfd: os.socket_t) !void {
    defer std.debug.print("close socket.\n", .{});
    defer os.closeSocket(clientfd);
    var loop = std.event.Loop.instance orelse return error.requires_evloop;
    var stream: util.Stream = .{ .handle = clientfd };
    var bfrReader = std.io.bufferedReader(stream.reader());
    //var bfrWriter = std.io.bufferedWriter(stream.writer());
    var reader = bfrReader.reader();
    //var writer = bfrWriter.writer();
    var info: [0x200]u8 = undefined;
    var bfr: [0x200]u8 = undefined;
    var body = ArrayList(u8).init(alloc);
    var headers = std.StringHashMap([]const u8).init(alloc);
    defer headers.deinit();
    defer body.deinit();

    var ctx: HttpContext = .{
        .fd = clientfd,
        .body = body.writer(),
        .method = undefined,
        .url = undefined,
        .allocator = alloc
    };

    var requests: u32 = 0;
    while (true) : (requests +%= 1) {
        if (true) {
            var line_ = try reader.readUntilDelimiter(info[0..], '\n');
            if (line_.len <= 1) return; // first line must be "method url"
            const line = line_[0..line_.len-1];
            var tokenize = std.mem.tokenize(u8, line, " ");
            ctx.method = tokenize.next() orelse return; // missing method
            ctx.url = tokenize.next() orelse return; // missing url
        }
        while (true) {
            var line = try reader.readUntilDelimiter(bfr[0..], '\n');
            if (line.len == 1) break;
            //var tokenize = std.mem.split(u8, line, ": ");
            //ctx.method = tokenize.next() orelse return; // missing method
            //ctx.url = tokenize.next() orelse return; // missing url
        }
        try handleRouting(&ctx);
        body.clearRetainingCapacity();
        // don't let a single client hog the pipe!
        if (requests % 0x100 == 0) {
            loop.yield();
        }
    }
}


fn handleRouting(ctx: *HttpContext) !void {
    //std.debug.print("req\n", .{});
    switch (urlRoute(ctx.url)) {
        route("/helloworld") => try handleHelloworld(ctx),
        route("/10-fortunes") => try handle10Fortunes(ctx),
        route("/all-fortunes") => try handleAllFortunes(ctx),
        route("/primes") => try handlePrimes(ctx),
        else => try handle404(ctx)
    }
}

fn sendContent(ctx: *HttpContext, data: []const u8) !void {
    var stream: Stream = .{ .handle = ctx.fd };
    var rawWriter = stream.writer();
    var writer = std.io.bufferedWriter(rawWriter);
    var bfr = writer.writer();

    try bfr.writeAll("HTTP/1.1 200 OK\r\nConnection: keep-alive\r\nContent-Length: ");
    try bfr.print("{d}", .{ data.len });
    try bfr.writeAll("\r\n\r\n");
    try bfr.writeAll(data);
    try writer.flush();
}

fn sendBody(ctx: *HttpContext) !void {
    try sendContent(ctx, ctx.body.context.items);
}


const fortunes10 = Pg.PreparedStatement(Fortune, .{
    .name = "a",
    .query = "select id, message from fortunes limit 10"
});
fn handle10Fortunes(ctx: *HttpContext) !void {
    _ = ctx;
    var pgclient = try pgpool.acquire();
    defer pgpool.release(pgclient);

    var jsstream = util.StreamingJsonArray.init();
    var query = try fortunes10.query(pgclient.value);
    while (try query.row()) |f| {
        try jsstream.write(f, ctx.body);
    }
    try jsstream.end(ctx.body);
    try sendBody(ctx);
}

const fortunesAll = Pg.PreparedStatement(Fortune, .{
    .name = "b",
    .query = "select id, message from fortunes"
});
fn handleAllFortunes(ctx: *HttpContext) !void {
    _ = ctx;
    var pgclient = try pgpool.acquire();
    defer pgpool.release(pgclient);

    var jsstream = util.StreamingJsonArray.init();
    var query = try fortunesAll.query(pgclient.value);
    while (try query.row()) |f| {
        try jsstream.write(f, ctx.body);
    }
    try jsstream.end(ctx.body);
    try sendBody(ctx);
}

fn handlePrimes(ctx: *HttpContext) !void {
    var a: u32 = 2;
    outer: while (a <= 10000) : (a += 1) {
        var b: u32 = 2;
        while (b < a) : (b += 1) {
            if (a % b == 0) continue :outer;
        }
        try ctx.body.print("{d}\n", .{ a });
    }
    try sendBody(ctx);
}

fn handle404(ctx: *HttpContext) !void {
    try sendContent(ctx, "404 not found");
}

fn handleHelloworld(ctx: *HttpContext) !void {
    try sendContent(ctx, "Hello, world");
}

fn urlRoute(url: []const u8) u64 {
    return std.hash.Wyhash.hash(0, url);
}

fn route(comptime url: []const u8) u64 {
    comptime {
        return std.hash.Wyhash.hash(0, url);
    }
}
