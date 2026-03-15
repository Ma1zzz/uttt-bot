const std = @import("std");

const Piece = enum(i32) { DOT = -1, EMPTY = 0, CROSS = 1 };

const RawBoardstate = extern struct {
    board: [9][9]Piece,
    turn: Piece,
    current: i16,
};

const Move = extern struct {
    sub: i32,
    spot: i32,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

export fn MaxBot(boardstate: RawBoardstate, _: *i32) Move {
    const allocator = gpa.allocator();
    _ = allocator;

    // TODO: translate boardstate → your internal representation
    // TODO: run MCTS until time_left is low
    // TODO: return best move

    const best: u8 = 0; // placeholder
    return Move{
        .sub = @intCast(best / 9),
        .spot = @intCast(best % 9),
    };
}
