const std = @import("std");
const os = std.os;
const builtin = @import("builtin");
const json = std.json;

pub extern "c" fn memcpy(to: [*]u8, from: [*]const u8, len: usize) *anyopaque;

pub const StreamingJsonArray = struct {
    started: bool,

    pub fn init() StreamingJsonArray {
        return StreamingJsonArray {
            .started = false
        };
    }

    pub fn write(self: *StreamingJsonArray, value: anytype, stream: anytype) !void {
        if (!self.started) {
            self.started = true;
            try stream.writeByte('[');
        } else {
            try stream.writeByte(',');
        }
        try json.stringify(value, .{}, stream);
    }

    pub fn end(self: *const StreamingJsonArray, stream: anytype) !void {
        if (!self.started) {
            try stream.writeByte('[');
        }
        try stream.writeByte(']');
    }
};

pub const Stream = struct {
    pub const ReadError = std.os.RecvFromError;
    pub const WriteError = std.os.SendError;
    pub const Reader = std.io.Reader(*Stream, ReadError, recv);
    pub const Writer = std.io.Writer(*Stream, WriteError, send);

    handle: std.os.socket_t,

    pub fn close(self: *Stream) void {
        std.os.closeSocket(self.handle);
    }

    pub fn reader(self: *Stream) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *Stream) Writer {
        return .{ .context = self };
    }

    pub fn recv(self: *Stream, buffer: []u8) ReadError!usize {
        const flags = if (builtin.os.tag == .macos) 0 else std.os.MSG.NOSIGNAL;
        while (true) {
            return std.os.recv(self.handle, buffer[0..], flags) catch |err| switch(err) {
                error.WouldBlock => {
                    if (std.event.Loop.instance) |loop| {
                        loop.waitUntilFdReadable(self.handle);
                        continue;
                    } else unreachable;
                },
                else => return err
            };
        }
    }

    pub fn send(self: *Stream, buffer: []const u8) WriteError!usize {
        const flags = if (builtin.os.tag == .macos) 0 else std.os.MSG.NOSIGNAL;
        while (true) {
            return std.os.send(self.handle, buffer[0..], flags) catch |err| switch(err) {
                error.WouldBlock => {
                    if (std.event.Loop.instance) |loop| {
                        loop.waitUntilFdWritable(self.handle);
                        continue;
                    } else unreachable;
                },
                else => return err
            };
        }
    }
};

pub const BfrStream = struct {
    const Self = BfrStream;
    pub const ReadError = std.os.RecvFromError;
    pub const WriteError = std.os.SendError;

    pub const Reader = std.io.Reader(*Self, ReadError, read);
    pub const Writer = std.io.Writer(*Self, WriteError, write);

    handle: std.os.fd_t,
    rb_data: [0x800]u8 = undefined,
    wb_data: [0x200]u8 = undefined,
    rb: []u8 = ([0]u8{})[0..],
    wb: usize = 0,

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *Self) Writer {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        const flags = if (builtin.os.tag == .linux) std.os.MSG.NOSIGNAL else 0;
        while (self.rb.len == 0) {
            const size = std.os.recv(self.handle, self.rb_data[0..], flags) catch |err| switch(err) {
                error.WouldBlock => {
                    if (std.event.Loop.instance) |loop| {
                        loop.waitUntilFdReadable(self.handle);
                        continue;
                    } else unreachable;
                },
                else => return err
            };
            self.rb = self.rb_data[0..size];
            if (size == 0) return size;
        }
        if (buf.len > self.rb.len) {
            const size = self.rb.len;
            _ = memcpy(buf.ptr, self.rb.ptr, buf.len);
            //std.mem.copy(u8, buf[0..], self.rb[0..]);
            self.rb.len = 0;
            return size;
        }
        _ = memcpy(buf.ptr, self.rb.ptr, buf.len);
        //std.mem.copy(u8, buf[0..], self.rb[0..buf.len]);
        self.rb = self.rb[buf.len..];
        return buf.len;
    }

    pub fn write(self: *Self, buf: []const u8) WriteError!usize {
        var base: [*]u8 = &self.wb_data;
        var remains = self.wb_data.len - self.wb;
        if (remains == 0) {
            try self.flush();
            remains = self.wb_data.len;
        }
        if (remains < buf.len) {
            _ = memcpy(base + self.wb, buf.ptr, remains);
            //std.mem.copy(u8, self.wb_data[self.wb..self.wb_data.len], buf[0..remains]);
            self.wb = self.wb_data.len;
            return remains;
        }
        _ = memcpy(base + self.wb, buf.ptr, buf.len);
        //std.mem.copy(u8, self.wb_data[self.wb..], buf[0..]);
        self.wb += buf.len;
        return buf.len;
    }
    
    pub fn flush(self: *Self) !void {
        const flags = if (builtin.os.tag == .linux) std.os.MSG.NOSIGNAL else 0;
        if (self.wb == 0) return;
        var written: usize = 0;
        while (written < self.wb) {
            const len = std.os.send(self.handle, self.wb_data[written..self.wb], flags) catch |err| switch(err) {
                error.WouldBlock => {
                    if (std.event.Loop.instance) |loop| {
                        loop.waitUntilFdWritable(self.handle);
                        continue;
                    } else unreachable;
                },
                else => return err
            };
            if (len == 0) break;
            written += len;
        }
        self.wb = 0;
    }
};

pub const BufferReader = struct {
    const Self = @This();
    buffer: []const u8,
    pos: usize = 0,

    pub fn readIntBig(self: *Self, comptime T: anytype) !T {
        defer self.pos += @sizeOf(T);
        return std.mem.readIntBig(T, self.buffer[self.pos..][0..@sizeOf(T)]);
    }

    pub fn readByte(self: *Self) !u8 {
        defer self.pos += 1;
        return self.buffer[self.pos];
    }

    pub fn seekBy(self: *Self, len: usize) !void {
        if (self.pos + len > self.buffer.len) {
            return error.EOF;
        }
        self.pos += len;
    }

    pub fn read(self: *Self, len: usize) ![]const u8 {
        if (self.pos + len > self.buffer.len) {
            return error.EOF;
        }
        defer self.pos += len;
        return self.buffer[self.pos..(self.pos + len)];
    }
};

