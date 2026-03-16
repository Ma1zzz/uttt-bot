const std = @import("std");

pub const Cell = enum(i8) { CROSS = 1, EMPTY = 0, DOT = -1 };

pub const Node = struct {
    nodes_under: []?*Node,
    parrent_node: ?*Node = null,
    pices: [81]Cell = .{.null} ** 81,
    points: i32 = 0,
    visits: u32 = 0,
    is_boot_node: bool = true,
    //  last_move: u8 = 0,
    move: u8 = 0,
};

pub const STILL_GOING: i8 = 2;

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

pub fn checkState(pieces: *const [81]Cell) i8 {
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

const sub_boards = [9][9]u8{
    .{ 0, 1, 2, 9, 10, 11, 18, 19, 20 },
    .{ 3, 4, 5, 12, 13, 14, 21, 22, 23 },
    .{ 6, 7, 8, 15, 16, 17, 24, 25, 26 },

    .{ 27, 28, 29, 36, 37, 38, 45, 46, 47 },
    .{ 30, 31, 32, 39, 40, 41, 48, 49, 50 },
    .{ 33, 34, 35, 42, 43, 44, 51, 52, 53 },

    .{ 54, 55, 56, 63, 64, 65, 72, 73, 74 },
    .{ 57, 58, 59, 66, 67, 68, 75, 76, 77 },
    .{ 60, 61, 62, 69, 70, 71, 78, 79, 80 },
};

const NEXT_SUBBOARD = [81]u8{
    0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 4, 5, 3, 4, 5, 3, 4, 5, 6, 7, 8, 6, 7, 8, 6, 7, 8,
    0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 4, 5, 3, 4, 5, 3, 4, 5, 6, 7, 8, 6, 7, 8, 6, 7, 8,
    0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 4, 5, 3, 4, 5, 3, 4, 5, 6, 7, 8, 6, 7, 8, 6, 7, 8,
};

// fn getNextSubBoard(position: u8) u8 {
//     return NEXT_SUBBOARD[position];
// }

pub fn getLegalMoves(current_board: *[81]u8, last_move: u8) [82]u8 { // 82 jeg bruger den sidste byte til at gemme mænden af legal moves
    //const last_move = current_node.last_move;
    //const current_board = current_node.pices;

    const sub_board_index = NEXT_SUBBOARD[last_move];

    var legal_moves = [_]u8{0} ** 82;
    var legal_move_index: u8 = 0;

    if (checkSubBoard(current_board, NEXT_SUBBOARD[last_move]) == STILL_GOING) {
        for (sub_boards[sub_board_index]) |value| {
            if (current_board[value] == Cell.EMPTY) {
                legal_moves[@intCast(legal_move_index)] = @intCast(value);
                legal_move_index += 1;
            }
        }

        legal_moves[81] = legal_move_index;
        return legal_moves;
    } else {
        for (sub_boards, 0..) |value, x| {
            if (checkSubBoard(current_board, x) != STILL_GOING) continue;

            for (value) |value2| {
                if (current_board[value2] == Cell.EMPTY) {
                    legal_moves[@intCast(legal_move_index)] = @intCast(value);
                    legal_move_index += 1;
                }
            }
        }
        legal_moves[81] = legal_move_index;
        return legal_moves;
    }
    unreachable;
}
