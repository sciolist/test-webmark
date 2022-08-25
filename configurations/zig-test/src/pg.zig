const std = @import("std");
const os = std.os;
const Allocator = std.mem.Allocator;
const utils = @import("./utils.zig");
const Stream = utils.BfrStream;

pub const ClientSettings = struct {
    host: []const u8,
    port: u16,
    user: []const u8,
    password: []const u8,
    database: []const u8,
};

const ClientState = enum { Disconnected, ReadyForQuery, Busy, Error };

const queryBoilerplate1 = [_]u8{
    'B', 0,   0, 0,   15,
    0,   'A', 0, 0,   0,
    0,   0,   0, 1,   0,
    1,   'D', 0, 0,   0,
    6,   'P', 0, 'E', 0,
    0,   0,   9, 0,   0,
    0,   0,   0, 'H', 0,
    0,   0,   4, 'S', 0,
    0,   0,   4,
};

const RegistrationsContext = struct {
    pub fn hash(ctx: RegistrationsContext, key: u64) u64 {
        _ = ctx;
        return key;
    }
    pub fn eql(ctx: RegistrationsContext, a: u64, b: u64) bool {
        _ = ctx;
        return a == b;
    }
};

const Registrations = std.hash_map.HashMap(u64, void, RegistrationsContext, 80);

pub const Client = struct {
    allocator: Allocator,
    data: std.ArrayList(u8) = undefined,
    settings: ClientSettings,
    stream: Stream = undefined,
    reader: Stream.Reader = undefined,
    writer: Stream.Writer = undefined,
    state: ClientState = ClientState.Disconnected,
    registrations: Registrations = undefined,

    pub fn init(allocator: Allocator, settings: ClientSettings) Client {
        return Client{
            .allocator = allocator,
            .settings = settings,
        };
    }

    pub fn deinit(self: *Client) void {
        self.disconnect();
    }

    pub fn connect(self: *Client) !void {
        if (self.state != .Disconnected) {
            return pgerrors.invalid_state;
        }

        self.data = std.ArrayList(u8).init(self.allocator);
        
        const sock = blk: {
            const addresses = try std.net.getAddressList(self.allocator, self.settings.host, self.settings.port);
            defer addresses.deinit();
            const address = addresses.addrs[0];
            break :blk try connectTo(address);
        };

        self.stream = .{ .handle = sock };
        self.writer = self.stream.writer();
        self.reader = self.stream.reader();

        const parameters = [_]KeyValuePair{
            .{ .key = "client_encoding", .value = "UTF8" },
            .{ .key = "user", .value = self.settings.user },
            //.{ .key = "password", .value = self.settings.password },
            .{ .key = "database", .value = self.settings.database },
        };

        self.registrations = Registrations.init(self.allocator);
        var startup = StartupPacket{ .parameters = parameters[0..] };
        try startup.write(self.writer);
        try self.stream.flush();

        var reader = self.reader;
        while (true) {
            const msg = try readMessageHeader(reader);
            switch (msg.typeid) {
                .Authentication => {
                    var buffer: [0x100]u8 = undefined;
                    var fba = std.heap.FixedBufferAllocator.init(buffer[0..]);
                    //const auth = try readMessageBody(msg, &fba.allocator, reader);
                    const auth = try deserialize(AuthenticationMessage, &fba.allocator(), reader);

                    if (auth.result != AuthenticationResult.Ok) {
                        std.debug.panic("auth failed: {s}\n", .{auth.result});
                    }
                },
                .ReadyForQuery => {
                    self.state = ClientState.ReadyForQuery;
                    try skipMessageBody(msg, reader);
                    return;
                },
                else => try self.processEvent(msg),
            }
        }
        unreachable;
    }

    pub fn disconnect(self: *Client) void {
        if (self.state == .Disconnected) {
            return;
        }
        self.state = .Disconnected;
        self.data.deinit();
        self.registrations.deinit();
        const terminate = SimpleMessage.init(MessageOutId.Terminate);
        terminate.write(self.writer) catch {};
        self.stream.flush() catch {};
        std.os.closeSocket(self.stream.handle);
        self.stream = undefined;
    }

    pub fn isQueryRegistered(self: *Client, key: u64) bool {
        if (self.state == .ReadyForQuery) {
            return self.registrations.contains(key);
        }
        return false;
    }

    pub fn registerQuery(self: *Client, key: u64) !void {
        try self.ensureReadyState();
        return try self.registrations.put(key, .{});
    }

    pub fn prepare(self: *Client, name: []const u8, queryText: []const u8) !void {
        try self.ensureReadyState();
        const emptyu32 = [0]u32{};
        const writer = self.writer;

        const parse: ParseMessage = .{
            .name = name,
            .query = queryText,
            .params = emptyu32[0..]
        };

        try parse.write(writer);
    }

    pub fn query(self: *Client, name: []const u8) ![]u8 {
        try self.ensureReadyState();
        const emptyu8 = [0]u8{};
        const emptyu16 = [0]u16{};

        const reader = self.reader;
        const writer = self.writer;

        const fmts = [1]u16{1};

        const bind: BindMessage = .{
            .portal = "",
            .statement = name,
            .paramformats = emptyu16[0..],
            .params = emptyu8[0..],
            .formats = fmts[0..],
        };

        const describe: DescribeMessage = .{
            .calltype = 'P',
            .name = ""
        };

        const execute: ExecuteMessage = .{
            .portal = "",
            .maxrows = 0
        };

        const flush = SimpleMessage.init(MessageOutId.Flush);
        const sync = SimpleMessage.init(MessageOutId.Sync);

        try bind.write(writer);
        try describe.write(writer);
        try execute.write(writer);
        try flush.write(writer);
        try sync.write(writer);
        try self.stream.flush();

        while (true) {
            const msg = try readMessageHeader(reader);
            switch (msg.typeid) {
                .RowDescription => {
                    var data = &self.data;
                    const len = msg.len - 4;
                    try data.resize(len);
                    _ = try reader.readAll(data.items[0..len]);
                    return data.items[0..len];
                },
                else => try self.processEvent(msg),
            }
        }
        unreachable;
    }

    fn ensureReadyState(self: *Client) !void {
        switch (self.state) {
            .Disconnected => try self.connect(),
            .ReadyForQuery => return,
            else => return pgerrors.bad
        }
    }

    fn processEvent(self: *Client, msg: MessageHeader) !void {
        const reader = self.reader;
        switch (msg.typeid) {
            .ParseComplete,
            .BindComplete,
            .ParameterStatus,
            .CommandComplete,
            .DataRow,
            .BackendKeyData => {
                try skipMessageBody(msg, reader);
            },
            .ReadyForQuery => {
                self.state = ClientState.ReadyForQuery;
                try skipMessageBody(msg, reader);
            },
            .Error => {
                const data = try self.allocator.alloc(u8, msg.len);
                defer self.allocator.free(data);
                _ = try self.reader.readAll(data[0..]);
                return pgerrors.bad;
            },
            else => {
                std.debug.panic("unhandled message type {s}", .{msg.typeid});
            },
        }
    }

    pub fn processEvents(self: *Client) !void {
        const reader = self.reader;
        while (true) {
            if (self.state == ClientState.ReadyForQuery and self.reader.fifo.readableLength() == 0) {
                return;
            }
            const msg = try readMessageHeader(reader);
            try self.processEvent(msg);
        }
    }
};

const KeyValuePair = struct { key: []const u8, value: []const u8 };

const StartupPacket = struct {
    version: u32 = 0x00030000,
    parameters: []const KeyValuePair,
    eof: u8 = 0,

    fn write(self: *StartupPacket, writer: anytype) !void {
        try writer.writeIntBig(u32, self.getLength());
        try writer.writeIntBig(u32, self.version);
        for (self.parameters) |kvp| {
            try writer.writeAll(kvp.key);
            try writer.writeByte(0);
            try writer.writeAll(kvp.value);
            try writer.writeByte(0);
        }
        try writer.writeByte(0);
    }

    fn getLength(self: *StartupPacket) u32 {
        var len: usize = 0;
        for (self.parameters) |kvp| {
            len += kvp.key.len + kvp.value.len + 2;
        }
        return @intCast(u32, len + (@sizeOf(u32) * 2) + 1);
    }
};


const BindMessage = struct {
    const Self = BindMessage;
    portal: []const u8,
    statement: []const u8,
    paramformats: []const u16,
    params: []const u8,
    formats: []const u16,

    fn write(self: *const Self, writer: anytype) !void {
        try writer.writeByte(@enumToInt(MessageOutId.Bind));
        try writer.writeIntBig(u32, @intCast(u32, self.getLength() + 4));
        try writer.writeAll(self.portal);
        try writer.writeByte(0);
        try writer.writeAll(self.statement);
        try writer.writeByte(0);

        try writer.writeIntBig(u16, @intCast(u16, self.paramformats.len));
        for (self.paramformats) |f| try writer.writeIntBig(u16, f);

        try writer.writeIntBig(u16, @intCast(u16, self.params.len));
        for (self.params) |f| try writer.writeIntBig(u16, f);
        
        try writer.writeIntBig(u16, @intCast(u16, self.formats.len));
        for (self.formats) |f| try writer.writeIntBig(u16, f);
    }

    fn getLength(self: *const Self) usize {
        return (
            self.portal.len + 1 +
            self.statement.len + 1 +
            @sizeOf(u16) +
            (@sizeOf(u16) * self.paramformats.len) +
            @sizeOf(u16) +
            (@sizeOf(u16) * self.params.len) +
            @sizeOf(u16) +
            (@sizeOf(u16) * self.formats.len)
        );
    }
};



const DescribeMessage = struct {
    const Self = DescribeMessage;
    calltype: u8,
    name: []const u8,

    fn write(self: *const Self, writer: anytype) !void {
        try writer.writeByte(@enumToInt(MessageOutId.Describe));
        try writer.writeIntBig(u32, @intCast(u32, self.getLength() + 4));
        try writer.writeByte(self.calltype);
        try writer.writeAll(self.name);
        try writer.writeByte(0);
    }

    fn getLength(self: *const Self) usize {
        return (
            1 +
            self.name.len + 1
        );
    }
};


const ParseMessage = struct {
    const Self = ParseMessage;
    name: []const u8,
    query: []const u8,
    params: []u32,

    fn write(self: *const Self, writer: anytype) !void {
        try writer.writeByte(@enumToInt(MessageOutId.Parse));
        try writer.writeIntBig(u32, @intCast(u32, self.getLength() + 4));
        try writer.writeAll(self.name);
        try writer.writeByte(0);
        try writer.writeAll(self.query);
        try writer.writeByte(0);
        try writer.writeIntBig(u16, @intCast(u16, self.params.len));
        for (self.params) |f| try writer.writeIntBig(u32, f);
    }

    fn getLength(self: *const Self) usize {
        return (
            self.name.len + 1 +
            self.query.len + 1 +
            @sizeOf(u16) +
            (@sizeOf(u32) * self.params.len)
        );
    }
};

const ExecuteMessage = struct {
    const Self = ExecuteMessage;
    portal: []const u8,
    maxrows: u32,

    fn write(self: *const Self, writer: anytype) !void {
        try writer.writeByte(@enumToInt(MessageOutId.Execute));
        try writer.writeIntBig(u32, @intCast(u32, self.getLength() + 4));
        try writer.writeAll(self.portal);
        try writer.writeByte(0);
        try writer.writeIntBig(u32, self.maxrows);
    }

    fn getLength(self: *const Self) usize {
        return (
            self.portal.len + 1 +
            @sizeOf(u32)
        );
    }
};

const SimpleMessage = struct {
    const Self = SimpleMessage;
    name: MessageOutId,

    fn init(name: MessageOutId) SimpleMessage {
        return .{ .name = name };
    }

    fn write(self: *const Self, writer: anytype) !void {
        try writer.writeByte(@enumToInt(self.name));
        try writer.writeIntBig(u32, 4);
    }
};

const pgerrors = error{ bad, invalid_state, unexpected_message, invalid_read_size };

const MessageInId = enum(u8) {
    Authentication = 'R',
    ParameterStatus = 'S',
    BackendKeyData = 'K',
    ReadyForQuery = 'Z',
    Error = 'E',
    ParseComplete = '1',
    BindComplete = '2',
    RowDescription = 'T',
    DataRow = 'D',
    PortalSuspended = 's',
    CommandComplete = 'C'
};

const AuthenticationResult = enum(u32) {
    Ok = 0,
    KerberosV5Required = 2,
    PasswordRequired = 3,
    MD5Required = 5,
    SCMRequired = 6,
    GSSRequired = 7,
    GSSContinue = 8,
    SSPIRequired = 9,
    SASLRequired = 10,
    SASLContinue = 11,
    SASLFinal = 12,
};

const AuthenticationMessage = struct { result: AuthenticationResult };

const MessageOutId = enum(u8) { Terminate = 'X', Bind = 'B', Parse = 'P', Execute = 'E', Flush = 'H', Describe = 'D', Sync = 'S' };

const Param = struct {
    len: u32,
    value: []const u8,
};

fn deserialize(
    comptime T: type,
    allocator: *std.mem.Allocator,
    stream: anytype,
) anyerror!T {
    switch (@typeInfo(T)) {
        .Int, .ComptimeInt => {
            return try stream.readIntBig(T);
        },
        .Bool => {
            return (try stream.readByte()) != 0;
        },
        .Enum => |E| return @intToEnum(T, try deserialize(E.tag_type, allocator, stream)),
        .Struct => |S| {
            var value: T = undefined;
            //if (comptime std.meta.trait.hasField("PGArray")(T)) {
            //    const LT = @TypeOf(@field(value, "len"));
            //    const DT = @typeInfo(@TypeOf(@field(value, "items"))).Pointer.child;
            //    const len = try stream.readIntBig(LT);
            //    @field(value, "len") = len;
            //    var al = try std.ArrayList(DT).initCapacity(allocator, len);
            //    var i: LT = 0;
            //    while (i < len) : (i += 1) {
            //        al.appendAssumeCapacity(try deserialize(DT, allocator, stream));
            //    }
            //    @field(value, "items") = al.toOwnedSlice();
            //    return value;
            //}

            inline for (S.fields) |Field| {
                if (Field.field_type == void) continue;
                @field(value, Field.name) = try deserialize(Field.field_type, allocator, stream);
            }
            return value;
        },
        .Pointer => |ptr_info| switch (ptr_info.size) {
            .Slice => {
                //if (ptr_info.child == u8) {
                //    return try stream.readUntilDelimiterAlloc(allocator, 0, 0x2000);
                //}

                @compileError("Unable to deserialize pointer to '" ++ @typeName(T) ++ "'");
            },
            else => @compileError("Unable to deserialize pointer to '" ++ @typeName(T) ++ "'"),
        },
        else => @compileError("Unable to deserialize type '" ++ @typeName(T) ++ "'"),
    }
    unreachable;
}

inline fn parseColumns2(
    comptime T: type,
    stream: anytype,
    reader: anytype,
) anyerror!T {
    switch (@typeInfo(T)) {
        .Int, .ComptimeInt => {
            const len = try reader.readIntBig(u32);
            if (len == std.math.maxInt(u32)) return undefined;
            return try reader.readIntBig(T);
        },
        .Bool => {
            const len = try reader.readIntBig(u32);
            if (len == std.math.maxInt(u32)) return undefined;
            return (try reader.readByte()) != 0;
        },
        .Enum => |E| return @intToEnum(T, try parseColumns2(E.tag_type, stream, reader)),
        .Struct => |S| {
            var value: T = undefined;
            inline for (S.fields) |Field| {
                // don't include void fields
                if (Field.field_type == void) continue;
                @field(value, Field.name) = try parseColumns2(Field.field_type, stream, reader);
            }
            return value;
        },
        .Pointer => |ptr_info| switch (ptr_info.size) {
            .Slice => {
                if (ptr_info.child == u8) {
                    const len = try reader.readIntBig(u32);
                    if (len == std.math.maxInt(u32)) return undefined;
                    const slice = stream.buffer[stream.pos..(stream.pos + len)];
                    try stream.seekBy(len);
                    return slice;
                }

                @compileError("Unable to deserialize pointer to '" ++ @typeName(T) ++ "'");
            },
            else => @compileError("Unable to deserialize pointer to '" ++ @typeName(T) ++ "'"),
        },
        else => @compileError("Unable to deserialize type '" ++ @typeName(T) ++ "'"),
    }
    unreachable;
}

inline fn parseColumns4(
    comptime T: type,
    reader: anytype,
) anyerror!T {
    switch (@typeInfo(T)) {
        .Int, .ComptimeInt => {
            const len = try reader.readIntBig(u32);
            if (len == std.math.maxInt(u32)) return undefined;
            return try reader.readIntBig(T);
        },
        .Bool => {
            const len = try reader.readIntBig(u32);
            if (len == std.math.maxInt(u32)) return undefined;
            return (try reader.readByte()) != 0;
        },
        .Enum => |E| return @intToEnum(T, try parseColumns4(E.tag_type, reader)),
        .Struct => |S| {
            var value: T = undefined;
            inline for (S.fields) |Field| {
                // don't include void fields
                if (Field.field_type == void) continue;
                @field(value, Field.name) = try parseColumns4(Field.field_type, reader);
            }
            return value;
        },
        .Pointer => |ptr_info| switch (ptr_info.size) {
            .Slice => {
                if (ptr_info.child == u8) {
                    const len = try reader.readIntBig(u32);
                    if (len == std.math.maxInt(u32)) return undefined;
                    return reader.read(len);
                }

                @compileError("Unable to deserialize pointer to '" ++ @typeName(T) ++ "'");
            },
            else => @compileError("Unable to deserialize pointer to '" ++ @typeName(T) ++ "'"),
        },
        else => @compileError("Unable to deserialize type '" ++ @typeName(T) ++ "'"),
    }
    unreachable;
}


inline fn parseColumns3(
    comptime T: type,
    data: [*]u8,
    pos: *usize
) anyerror!T {
    switch (@typeInfo(T)) {
        .Int, .ComptimeInt => {
            const len = std.mem.readIntBig(u32, data[pos.*..(pos.*+4)][0..4]);
            pos.* += 4;
            if (len == std.math.maxInt(u32)) return undefined;
            defer pos.* += len;
            return std.mem.readIntBig(T, data[pos.*..(pos.*+@sizeOf(T))][0..@sizeOf(T)]);
        },
        .Bool => {
            const len = std.mem.readIntBig(u32, data[pos.*..(pos.*+4)][0..4]);
            pos.* += 4;
            if (len == std.math.maxInt(u32)) return undefined;
            defer pos.* += len;
            return data[pos] != 0;
        },
        .Enum => |E| return @intToEnum(T, try parseColumns3(E.tag_type, data, pos)),
        .Struct => |S| {
            var value: T = undefined;
            inline for (S.fields) |Field| {
                // don't include void fields
                if (Field.field_type == void) continue;
                @field(value, Field.name) = try parseColumns3(Field.field_type, data, pos);
            }
            return value;
        },
        .Pointer => |ptr_info| switch (ptr_info.size) {
            .Slice => {
                if (ptr_info.child == u8) {
                    const len = std.mem.readIntBig(u32, data[pos.*..(pos.*+4)][0..4]);
                    pos.* += 4;
                    if (len == std.math.maxInt(u32)) return undefined;
                    defer pos.* += len;
                    const slice = data[pos.*..(pos.* + len)];
                    return slice;
                }

                @compileError("Unable to deserialize pointer to '" ++ @typeName(T) ++ "'");
            },
            else => @compileError("Unable to deserialize pointer to '" ++ @typeName(T) ++ "'"),
        },
        else => @compileError("Unable to deserialize type '" ++ @typeName(T) ++ "'"),
    }
    unreachable;
}

const MessageHeader = struct { typeid: MessageInId, len: u32 };

fn skipMessageBody(header: MessageHeader, datareader: anytype) !void {
    try datareader.skipBytes(header.len - 4, .{});
}

fn readMessageHeader(reader: anytype) !MessageHeader {
    const typeid = try reader.readByte();
    return MessageHeader{ .typeid = @intToEnum(MessageInId, typeid), .len = try reader.readIntBig(u32) };
}

fn skipMessage(reader: anytype) !void {
    const header = try readMessageHeader(reader);
    try skipMessageBody(header, reader);
}

const PreparedStatementOptions = struct {
    name: []const u8,
    query: []const u8,
};

pub fn QueryResponse(comptime T: type) type {
    return struct {
        const Self = @This();
        client: *Client,

        pub fn init(client: *Client) Self {
            return Self{ .client = client };
        }

        pub fn rowd(self: *Self) !?[]u8 {
            var data = &self.client.data;
            const reader = self.client.reader;
            while (true) {
                const msg = try readMessageHeader(reader);
                switch (msg.typeid) {
                    .DataRow => {
                        const len = msg.len - 4;
                        try data.resize(len);
                        _ = try reader.readAll(data.items[0..len]);
                        return data.items[0..len];
                    },
                    .CommandComplete => {
                        try skipMessageBody(msg, reader);
                        return null;
                    },
                    else => try self.client.processEvent(msg),
                }
            }
        }

        pub fn row(self: *Self) !?T {
            var data = &self.client.data;
            data.clearRetainingCapacity();
            const reader = self.client.reader;
            while (true) {
                const msg = try readMessageHeader(reader);
                switch (msg.typeid) {
                    .DataRow => {
                        const len = msg.len - 4;
                        try data.ensureTotalCapacity(len);
                        _ = try reader.readAll(data.items.ptr[0..len]);
                        
                        var fba = std.io.fixedBufferStream(data.items.ptr[2..len]);
                        var freader = fba.reader();
                        return try parseColumns2(T, &fba, &freader);
                        
                        //var freader: utils.BufferReader = .{ .buffer = data.items.ptr[2..len] };
                        //const result = try parseColumns4(T, &freader);
                        //return result;
                        
                        //var at: usize = 2;
                        //return try parseColumns3(T, data.items.ptr, &at);
                    },
                    .CommandComplete => {
                        try skipMessageBody(msg, reader);
                        return null;
                    },
                    else => try self.client.processEvent(msg),
                }
            }
        }
    };
}

pub fn PreparedStatement(comptime T: type, comptime options: PreparedStatementOptions) type {
    const hashedname = comptime std.hash.Wyhash.hash(0, options.name);
    return struct {
        pub fn query(pg: *Client) !QueryResponse(T) {
            if (!pg.isQueryRegistered(hashedname)) {
                try pg.prepare(options.name, options.query);
                try pg.registerQuery(hashedname);
            }
            _ = try pg.query(options.name);
            return QueryResponse(T).init(pg);
        }
    };
}

fn connectTo(address: std.net.Address) !std.os.socket_t {
    const opt_non_block = if (std.io.is_async) std.os.SOCK.NONBLOCK else 0;
    const sock = try std.os.socket(
        std.os.AF.INET,
        std.os.SOCK.STREAM | opt_non_block,
        std.os.IPPROTO.TCP
    );

    if (@hasDecl(os.TCP, "QUICKACK")) {
        try os.setsockopt(sock, os.IPPROTO.TCP, os.TCP.QUICKACK, std.mem.asBytes(&@as(usize, @boolToInt(true))));
    }
    if (@hasDecl(os.TCP, "NODELAY")) {
        try os.setsockopt(sock, os.IPPROTO.TCP, os.TCP.NODELAY, std.mem.asBytes(&@as(usize, @boolToInt(true))));
    }
    if (@hasDecl(os.SO, "NOSIGPIPE")) {
        try os.setsockopt(sock, os.SOL.SOCKET, os.SO.NOSIGPIPE, std.mem.asBytes(&@as(usize, @boolToInt(true))));
    }

    std.os.connect(sock, &address.any, address.getOsSockLen()) catch |err| switch(err) {
        error.WouldBlock => {
            if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdWritable(sock);
                try std.os.getsockoptError(sock);
            } else unreachable;
        },
        else => return err
    };

    return sock;
}
