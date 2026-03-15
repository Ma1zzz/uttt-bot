const std = @import("std");

const Cell = enum(i8) { CROSS = 1, EMPTY = 0, DOT = -1 };

const Node = struct {
    nodes_under: []?*Node,
    parrent_node: ?*Node = null,
    pices: [81]Cell = .{.null} ** 81,
    points: i32 = 0,
    visits: u32 = 0,
    is_boot_nide: bool = true,
    last_move: u8,
};

const STILL_GOING: i8 = 2;

const win_lines = [8][3]usize{
    .{ 0, 1, 2 }, .{ 3, 4, 5 }, .{ 6, 7, 8 },
    .{ 0, 3, 6 }, .{ 1, 4, 7 }, .{ 2, 5, 8 },
    .{ 0, 4, 8 }, .{ 2, 4, 6 },
};

fn checkSubBoard(pieces: *const [81]Cell, board_idx: usize) i8 {
    const base = board_idx * 9;
    for (win_lines) |line| {
        const a = @intFromEnum(pieces[base + line[0]]);
        const b = @intFromEnum(pieces[base + line[1]]);
        const c = @intFromEnum(pieces[base + line[2]]);
        if (a != 0 and a == b and b == c) return a;
    }
    for (0..9) |i| {
        if (pieces[base + i] == .EMPTY) return STILL_GOING;
    }
    return 0;
}

fn checkState(pieces: *const [81]Cell) i8 {
    var meta: [9]i8 = undefined;
    for (0..9) |b| meta[b] = checkSubBoard(pieces, b);

    for (win_lines) |line| {
        const a = meta[line[0]];
        const b = meta[line[1]];
        const c = meta[line[2]];
        if (a != 0 and a != STILL_GOING and a == b and b == c) return a;
    }
    for (meta) |m| {
        if (m == STILL_GOING) return STILL_GOING;
    }
    return 0;
}
