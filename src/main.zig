const std = @import("std");
const Trie = @import("trie.zig");

pub fn main() !void {
    const page_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (std.os.argv.len < 2) {
        std.debug.print("Usage: {s} <file>\n", .{std.os.argv[0]});
        return;
    }

    const filename = std.mem.span(std.os.argv[1]);
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const buffer = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(buffer);

    var trie = try Trie.Trie.create(allocator);
    defer trie.destroy();

    var it = std.mem.tokenizeScalar(u8, buffer, '\n');
    while (it.next()) |word| {
        if (word.len > 0) {
            try trie.insert(word);
        }
    }

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    while (true) {
        try stdout.print("Enter a prefix to see suggestions (or 'exit' to quit):\n", .{});
        try stdout.print("Prefix: ", .{});

        var prefix_buffer = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(u8)) orelse break;
        defer allocator.free(prefix_buffer);

        if (prefix_buffer.len > 0 and prefix_buffer[prefix_buffer.len - 1] == '\n') {
            prefix_buffer = prefix_buffer[0 .. prefix_buffer.len - 1];
        }

        if (std.mem.eql(u8, prefix_buffer, "exit")) {
            break;
        }

        for (0..prefix_buffer.len) |i| {
            prefix_buffer[i] = std.ascii.toLower(prefix_buffer[i]);
        }

        var suggestions = try trie.suggest(prefix_buffer, allocator);
        defer suggestions.deinit();

        if (suggestions.items.len == 0) {
            try stdout.print("No suggestions found.\n", .{});
        } else {
            try stdout.print("For the prefix '{s}' there are {d} suggestions:\n", .{ prefix_buffer, suggestions.items.len });
            for (suggestions.items) |suggestion| {
                try stdout.print("{s}\n", .{suggestion});
                allocator.free(suggestion);
            }
        }
    }
}
