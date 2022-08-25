const std = @import("std");
const builtin = @import("builtin");
const pg = @import("./pg.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;

pub fn ObjectPool(comptime T: type, initializer: fn(allocator: std.mem.Allocator) anyerror!*T, limit: u32, threadsafe: bool) type {
    const Mutex = if (threadsafe) std.Thread.Mutex else std.Thread.Mutex.Dummy;
    return struct {
        const Node = struct {
            value: *T,
            node: *ItemQueue.Node
        };
        const Waiter = struct {
            frame: *@Frame(acquire),
            node: ?Node
        };
        const ItemQueue = std.TailQueue(*T);
        const CreateQueue = std.TailQueue(*ItemQueue.Node);
        const PendingQueue = std.TailQueue(*Waiter);
        const Self = @This();
        allocator: std.mem.Allocator,
        items: ItemQueue,
        pending: PendingQueue,
        created: CreateQueue,
        tocreate: u32 = limit,
        mutex: Mutex,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self {
                .mutex = Mutex{},
                .created = .{},
                .items = .{},
                .pending = .{},
                .allocator = allocator
            };
        }

        pub fn deinit(self: *Self) void {
            while (self.created.pop()) |node| {
                var obj = node.data.data;
                if (std.meta.trait.hasFn("deinit")(T)) {
                    obj.deinit();
                }
                self.allocator.destroy(obj);
                self.allocator.destroy(node);
            }
        }

        fn initialize(self: *Self) !*ItemQueue.Node {
            var node = try self.allocator.create(ItemQueue.Node);
            var cnode = try self.allocator.create(CreateQueue.Node);
            errdefer self.allocator.destroy(cnode);
            errdefer self.allocator.destroy(node);
            var data = try initializer(self.allocator);
            self.mutex.lock();
            self.created.append(cnode);
            self.mutex.unlock();
            cnode.data = node;
            node.data = data;
            return node;
        }

        pub fn acquire(self: *Self) !Node {
            self.mutex.lock();
            if (self.items.pop()) |node| {
                self.mutex.unlock();
                return Node { .value = node.data, .node = node };
            }
            if (@atomicLoad(u32, &self.tocreate, .Monotonic) > 0) {
                self.mutex.unlock();
                _ = @atomicRmw(u32, &self.tocreate, .Sub, 1, .Monotonic);
                var node = self.initialize() catch |err| {
                    _ = @atomicRmw(u32, &self.tocreate, .Add, 1, .Monotonic);
                    return err;
                };
                return Node { .value = node.data, .node = node };
            }
            var waiter = Waiter {
                .frame = @frame(),
                .node = null
            };
            suspend {
                var instance: PendingQueue.Node = .{ .data = &waiter };
                self.pending.prepend(&instance);
                self.mutex.unlock();
            }
            if (waiter.node) |n| {
                return n;
            }
            unreachable;
        }

        pub fn release(self: *Self, value: Node) void {
            if (builtin.mode == .Debug) {
                self.mutex.lock();
                defer self.mutex.unlock();
                var head = self.items.first;
                while (head) |h| {
                    if (h.data == value.node.data) {
                        @panic("double release");
                    }
                    head = h.next;
                }
            }
            self.mutex.lock();
            if (self.pending.pop()) |pending| {
                pending.data.node = value;
                self.mutex.unlock();
                resume pending.data.frame;
            } else {
                self.items.prepend(value.node);
                self.mutex.unlock();
            }
        }
    };
}
