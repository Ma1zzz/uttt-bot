const std = @import("std");
const mcts = @import("mcts.zig");
const board = @import("board.zig");
const Node = board.Node;

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

const backing_allocator = gpa.allocator();
var arena = std.heap.ArenaAllocator.init(backing_allocator);
const allocator = arena.allocator();

var is_first_time: bool = true;
var root_node: Node = {};

var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
const rand = prng.random();

export fn MaxBot(boardstate: RawBoardstate, _: *i32) Move {
    if (is_first_time) {
        var idx: usize = 0;
        for (boardstate.board) |row| {
            for (row) |cell| {
                if (cell != .EMPTY) {
                    return idx;
                }
                idx += 1;
            }
        }
        root_node.parrent_node = null;
        root_node.move = idx;
        is_first_time = false;
    }

    const other_move = getOpponentMove(root_node.pices, &RawBoardstate);

    for (root_node.nodes_under) |value| {
        if (value.?.move != other_move) continue;
        root_node = root_node.nodes_under;
    }

    var x: usize = 0;
    while (x < 1000000) : (x += 1) {
        mcts.selection(root_node, allocator, rand);
    }

    const best: u8 = mcts.pickStep(&root_node);
    return Move{
        .sub = @intCast(best / 9),
        .spot = @intCast(best % 9),
    };
}

fn getOpponentMove(our_pieces: [81]board.Cell, raw: *const RawBoardstate) u8 {
    for (0..81) |i| {
        const row = i / 9;
        const col = i % 9;
        const raw_cell = raw.board[row][col];
        // convert raw_cell to your Cell type and compare
        if (our_pieces[i] == .EMPTY and raw_cell != .EMPTY) {
            return @intCast(i);
        }
    }
    unreachable; // should always find a difference
}
