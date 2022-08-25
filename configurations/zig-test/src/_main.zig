const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const os = std.os;
const mem = std.mem;
const Pg = @import("./pg.zig");
const utils = @import("./utils.zig");
const ObjectPool = @import("./object_pool.zig").ObjectPool;
//const PGPool = ObjectPool(Pg.Client, pgConnect, 0x100, false);

//pub const io_mode = .evented;


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


//threadlocal var pgpool: PGPool = PGPool.init(std.heap.c_allocator);

const Fortune = struct {
    id: u32,
    message: []const u8
};

const fortunes10 = Pg.PreparedStatement(Fortune, .{
    .name = "a",
    .query = "select id, message from fortunes limit 10"
});

var alloc: std.mem.Allocator = std.heap.c_allocator;

pub fn main() !void {
    var i: usize = 0;
    var started = std.time.milliTimestamp();
    //var client = try pgpool.acquire();
    //defer pgpool.release(client);

    var client = try pgConnect(alloc);
    
    while (true) : (i += 1) {
        var now = std.time.milliTimestamp();
        if (now - started >= 1000) {
            std.debug.print(": {d}\n", .{ i });
            i = 0;
            started = now;
        }

        //var jsstream = utils.StreamingJsonArray.init();
        var query = try fortunes10.query(client);
        while (try query.row()) |f| {
            //try jsstream.write(f, stdout);
            _ = f;
        }
        //try jsstream.end(stdout);
    }
}
