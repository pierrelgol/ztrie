const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const ALPHABET_SIZE: usize = 26;

pub const TrieNode = struct {
    children: [ALPHABET_SIZE]?*TrieNode,
    is_end_of_word: bool,

    pub fn create(allocator: Allocator) Allocator.Error!*TrieNode {
        var result = try allocator.create(TrieNode);
        @memset(result.children[0..], null);
        result.is_end_of_word = false;
        return result;
    }

    pub fn destroy(self: *TrieNode, allocator: Allocator) void {
        for (self.children) |maybe_child| {
            if (maybe_child) |child| {
                child.destroy(allocator);
            }
        }
        allocator.destroy(self);
    }

    pub fn isEmpty(self: *TrieNode) bool {
        for (self.children) |maybe_child| {
            if (maybe_child) return (false);
        }
        return (true);
    }

    pub fn removeChild(maybe_self: ?*TrieNode, allocator: Allocator, key: []const u8) bool {
        const self = maybe_self orelse return false;
        if (key.len == 0) {
            if (self.is_end_of_word) {
                self.is_end_of_word = false;
                if (self.isEmpty()) {
                    allocator.destroy(self);
                    return (true);
                } else {
                    return (false);
                }
            }
        } else {
            const index = (key[0] | 32) - ('a' | 32);
            if (self.removeChild(self.children[index], allocator, key[1..])) {
                self.children[index] = null;
                return (!self.is_end_of_word and self.isEmpty());
            }
        }
        return (false);
    }

    pub fn findPrefixNode(self: *TrieNode, key: []const u8) ?*TrieNode {
        var maybe_next: ?*TrieNode = self;
        for (key) |char| {
            const index = (char | 32) - ('a' | 32);
            const next = maybe_next orelse return (null);
            maybe_next = next.children[index];
        }
        return (maybe_next orelse null);
    }

    pub fn buildPrefix(allocator: Allocator, prefix: []const u8, new_char: u8) ![]u8 {
        var result = try allocator.alloc(u8, prefix.len + 1);
        @memcpy(result[0..prefix.len], prefix);
        result[prefix.len] = new_char;
        return (result);
    }

    pub fn collectSuggestions(maybe_self: ?*TrieNode, prefix: []const u8, allocator: Allocator, collector: *std.ArrayList([]const u8)) !void {
        const self = maybe_self orelse return;
        if (self.is_end_of_word) {
            try (collector.append(prefix));
        }
        for (self.children, 0..) |maybe_child, i| {
            const child = maybe_child orelse continue;
            const suggestion = try TrieNode.buildPrefix(allocator, prefix, @truncate('a' + i));
            try child.collectSuggestions(suggestion, allocator, collector);
        }
    }
};

pub const Trie = struct {
    maybe_root: ?*TrieNode,
    allocator: Allocator,

    pub fn create(allocator: Allocator) Allocator.Error!*Trie {
        var self = try allocator.create(Trie);
        self.maybe_root = null;
        self.allocator = allocator;
        return self;
    }

    pub fn destroy(self: *Trie) void {
        if (self.maybe_root) |root| {
            root.destroy(self.allocator);
        }
        self.allocator.destroy(self);
    }

    pub fn insert(self: *Trie, key: []const u8) !void {
        if (self.maybe_root == null) {
            self.maybe_root = try TrieNode.create(self.allocator);
        }

        var node = self.maybe_root orelse unreachable;
        for (key) |char| {
            const index = (char | 32) - ('a' | 32);
            if (node.children[index] == null) {
                node.children[index] = try TrieNode.create(self.allocator);
            }
            node = node.children[index] orelse unreachable;
        }
        node.is_end_of_word = true;
    }

    pub fn search(self: *Trie, key: []const u8) bool {
        var node = self.maybe_root orelse return (false);
        for (key) |char| {
            const index = (char | 32) - ('a' | 32);
            if (node.children[index] == null) {
                return (false);
            }
            node = node.children[index] orelse return (false);
        }
        return (node.is_end_of_word);
    }

    pub fn remove(self: *Trie, key: []const u8) bool {
        return (TrieNode.removeChild(self.maybe_root, self.allocator, key));
    }

    pub fn suggest(self: *Trie, prefix: []const u8, allocator: Allocator) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).init(allocator);
        const root = self.maybe_root orelse return result;
        const prefix_node = root.findPrefixNode(prefix) orelse return result;
        try prefix_node.collectSuggestions(prefix, allocator, &result);
        return (result);
    }
};
