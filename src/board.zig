const std = @import("std");

pub const Cell = enum(i8) { CROSS = 1, EMPTY = 0, DOT = -1 };

pub const Node = struct {
    nodes_under: []?*Node,
    parrent_node: ?*Node = null,
    pices: [81]Cell = .{Cell.EMPTY} ** 81,
    points: i32 = 0,
    visits: i32 = 0,
    is_boot_node: bool = true,

    move: u8 = 0,
};

pub const STILL_GOING: i8 = 2;

const win_lines = [8][3]usize{
    .{ 0, 1, 2 }, .{ 3, 4, 5 }, .{ 6, 7, 8 },
    .{ 0, 3, 6 }, .{ 1, 4, 7 }, .{ 2, 5, 8 },
    .{ 0, 4, 8 }, .{ 2, 4, 6 },
};

const lookup = buildLookupTable();

fn buildLookupTable() [19683]i8 {
    @setEvalBranchQuota(1000000);
    var table: [19683]i8 = undefined;

    for (0..19683) |board_num| {
        // decode board_num back into 9 cells
        var cells: [9]Cell = undefined;
        var n = board_num;
        for (0..9) |i| {
            cells[i] = switch (n % 3) {
                0 => Cell.EMPTY,
                1 => Cell.CROSS,
                else => Cell.DOT,
            };
            n /= 3;
        }
        table[board_num] = checkWinner(cells);
    }

    return table;
}

fn checkWinner(cells: [9]Cell) i8 {
    for (win_lines) |line| {
        const a = cells[line[0]];
        const b = cells[line[1]];
        const c = cells[line[2]];
        if (a != .EMPTY and a == b and b == c) {
            return if (a == .CROSS) 1 else -1;
        }
    }
    for (cells) |cell| {
        if (cell == .EMPTY) return STILL_GOING;
    }
    return 0; // draw
}

inline fn cellToDigit(cell: Cell) usize {
    return switch (cell) {
        .EMPTY => 0,
        .CROSS => 1,
        .DOT => 2,
    };
}

const pow3 = [9]usize{ 1, 3, 9, 27, 81, 243, 729, 2187, 6561 };

pub inline fn checkSubBoard(pieces: *const [81]Cell, board_idx: usize) i8 {
    var n: usize = 0;
    for (sub_boards[board_idx], 0..) |pi, i| {
        n += cellToDigit(pieces[pi]) * pow3[i];
    }
    return lookup[n];
}

pub inline fn checkState(pieces: *const [81]Cell) i8 {
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
pub const sub_boards = [9][9]u8{
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

pub const NEXT_SUBBOARD = [81]u8{
    0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 4, 5, 3, 4, 5, 3, 4, 5, 6, 7, 8, 6, 7, 8, 6, 7, 8,
    0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 4, 5, 3, 4, 5, 3, 4, 5, 6, 7, 8, 6, 7, 8, 6, 7, 8,
    0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 4, 5, 3, 4, 5, 3, 4, 5, 6, 7, 8, 6, 7, 8, 6, 7, 8,
};

pub inline fn getLegalMoves(current_board: *const [81]Cell, current: i16) [82]u8 {
    var legal_moves: [82]u8 = undefined;
    var legal_move_index: u8 = 0;

    // fast path - just check one sub
    if (current != -1) {
        const sub: usize = @intCast(current);
        if (checkSubBoard(current_board, sub) == STILL_GOING) {
            for (sub_boards[sub]) |value| {
                if (current_board[value] == Cell.EMPTY) {
                    legal_moves[legal_move_index] = @intCast(value);
                    legal_move_index += 1;
                }
            }
            legal_moves[81] = legal_move_index;
            return legal_moves;
        }
    }

    // slow path - check all subs, but only once each
    var sub_results: [9]i8 = undefined;
    for (0..9) |x| sub_results[x] = checkSubBoard(current_board, x);

    for (win_lines) |line| {
        const a = sub_results[line[0]];
        const b = sub_results[line[1]];
        const c = sub_results[line[2]];
        if (a != STILL_GOING and a != 0 and a == b and b == c) {
            legal_moves[81] = 0;
            return legal_moves;
        }
    }

    for (sub_boards, 0..) |value, x| {
        if (sub_results[x] != STILL_GOING) continue;
        for (value) |value2| {
            if (current_board[value2] == Cell.EMPTY) {
                legal_moves[legal_move_index] = value2;
                legal_move_index += 1;
            }
        }
    }
    legal_moves[81] = legal_move_index;
    return legal_moves;
}
// pub inline fn getLegalMoves(current_board: *const [81]Cell, current: i16) [82]u8 { // 82 jeg bruger den sidste byte til at gemme mænden af legal moves
//
//     var legal_moves: [82]u8 = undefined;
//     var legal_move_index: u8 = 0;
//
//     if (current != -1) {
//         const sub_board_index: usize = @intCast(current);
//         if (checkSubBoard(current_board, sub_board_index) == STILL_GOING) {
//             for (sub_boards[sub_board_index]) |value| {
//                 if (current_board[value] == Cell.EMPTY) {
//                     legal_moves[legal_move_index] = @intCast(value);
//                     legal_move_index += 1;
//                 }
//             }
//             legal_moves[81] = legal_move_index;
//             return legal_moves;
//         }
//     }
//     for (sub_boards, 0..) |value, x| {
//         if (checkSubBoard(current_board, x) != STILL_GOING) continue;
//         for (value) |value2| {
//             if (current_board[value2] == Cell.EMPTY) {
//                 legal_moves[legal_move_index] = value2;
//                 legal_move_index += 1;
//             }
//         }
//     }
//     legal_moves[81] = legal_move_index;
//     return legal_moves;
// }
