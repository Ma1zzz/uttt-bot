const std = @import("std");
const mcts = @import("mcts.zig");
const board = @import("board.zig");
const Node = board.Node;

const Piece = enum(i32) { DOT = -1, EMPTY = 0, CROSS = 1 };

const StdVector = extern struct {
    ptr: [*]u8,
    size: usize,
    capacity: usize,
};

const RawBoardstate = extern struct {
    board: StdVector, // outer vector
    turn: i32,
    current: i16,
};

const Move = extern struct {
    sub: i32,
    spot: i32,
};

var is_first_time: bool = true;

export fn libmcts_bot(boardstate: *const RawBoardstate, _: *i32) Move {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const backing_allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(backing_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var root_node: Node = .{
        .parrent_node = null,
        .pices = .{board.Cell.EMPTY} ** 81,
        .is_boot_node = false,
        .nodes_under = &.{},
    };

    root_node.pices = rawToBoard(boardstate);

    if (boardstate.turn == 1) {
        mcts.bot_piece = board.Cell.CROSS;
        mcts.opponent_piece = board.Cell.DOT;
    } else if (boardstate.turn == -1) {
        mcts.bot_piece = board.Cell.DOT;
        mcts.opponent_piece = board.Cell.CROSS;
    }

    std.debug.print("__{}__\n", .{boardstate.turn});

    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    const rand = prng.random();

    const start = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - start < 9000) {
        mcts.selection(&root_node, allocator, rand, boardstate.current) catch {
            std.debug.print("yeah YORE fucked bitch", .{});
            unreachable;
        };
    }

    std.debug.print("TOTAL LITS {}\n", .{root_node.visits});

    for (root_node.nodes_under) |value| {
        std.debug.print("move : {}\n", .{value.?.move});
    }

    for (root_node.nodes_under) |value| {
        std.debug.print(
            "Nodes move {} had {} visits and {} points\n thats a winrate of {}\n",
            .{ value.?.move, value.?.visits, value.?.points, @as(f32, @floatFromInt(value.?.points)) /
                @as(f32, @floatFromInt(value.?.visits)) },
        );
    }

    const best_child_index: u8 = mcts.pickStep(&root_node);
    const best = root_node.nodes_under[best_child_index].?.move;

    var best_sub: i32 = 0;
    var move: i32 = 0;
    for (board.sub_boards, 0..) |sub_boards, y| {
        for (sub_boards, 0..) |value, z| {
            if (value == best) {
                best_sub = @intCast(y);
                move = @intCast(z);
            }
        }
    }

    return .{
        .sub = best_sub,
        .spot = move,
    };
}

fn getRawCell(raw: *const RawBoardstate, row: usize, col: usize) i32 {
    const inner_vectors = @as([*]StdVector, @ptrCast(@alignCast(raw.board.ptr)));
    const row_vec = inner_vectors[row];
    const pieces = @as([*]i32, @ptrCast(@alignCast(row_vec.ptr)));
    return pieces[col];
}

fn rawToBoard(raw: *const RawBoardstate) [81]board.Cell {
    var pices = [_]board.Cell{board.Cell.EMPTY} ** 81;
    for (0..9) |sub| {
        for (0..9) |cell| {
            const board_row = sub / 3;
            const board_col = sub % 3;
            const cell_row = cell / 3;
            const cell_col = cell % 3;
            const flat: u8 = @intCast((board_row * 3 + cell_row) * 9 + (board_col * 3 + cell_col));
            pices[flat] = switch (getRawCell(raw, sub, cell)) {
                1 => board.Cell.CROSS,
                -1 => board.Cell.DOT,
                else => board.Cell.EMPTY,
            };
        }
    }
    return pices;
}
