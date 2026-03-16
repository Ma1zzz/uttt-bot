const std = @import("std");
const board = @import("board.zig");
const Node = board.Node;

pub fn selection(root_node: *Node, allocator: std.mem.Allocator, rand: std.Random) !void {
    try createNewNodes(allocator, root_node);

    // lav kun legal moves som nodes nodes_under

    var ucb1Val = [root_node.nodes_under.len]f64{0} ** root_node.nodes_under.len;
    //const bored = root_node.pices;

    for (root_node.nodes_under, 0..) |value, x| {
        ucb1Val[x] = ucb1(value.?.points, value.?.visits, root_node.visits);
    }
    var best_index: usize = 99;
    var max_ucb: f64 = -999999;

    for (ucb1Val, 0..) |value, i| {
        if (value >= max_ucb) {
            max_ucb = value;
            best_index = i;
        }
    }

    if (board.checkState(&root_node.bored) != board.STILL_GOING) {
        const current_score = board.checkState(&root_node.bored);
        backMove(root_node, current_score);
        return;
    }

    if (best_index == 99) unreachable;
    const node = root_node.nodes_under[best_index].?;
    if (node.visits != 0) return selection(root_node.nodes_under[best_index].?, allocator, rand);
    if (node.visits == 0) {
        simulate(node, rand);
        return;
    }

    unreachable;
}

fn simulate(start_node: *Node, rand: std.Random) void {
    const score = playOut(start_node.pices, start_node.is_bot, rand, start_node.parrent_node.?.move);
    backMove(start_node, score);
    return;
}

fn playOut(current_board: [81]u8, is_bot_turn: bool, rand: std.Random, last_move: u8) i8 {
    const x = board.checkState(&current_board);
    switch (x) {
        board.STILL_GOING => {},
        else => {
            return x;
        },
    }

    const legal_moves = board.getLegalMoves(&current_board, last_move);
    const legal_moves_amount = legal_moves[81];

    const value = rand.intRangeLessThan(usize, 0, legal_moves_amount);
    const move = legal_moves[value];

    var new_board = current_board;

    if (is_bot_turn) {
        new_board[move] = board.Cell.DOT;
    } else {
        new_board[move] = board.Cell.CROSS;
    }

    return playOut(new_board, !is_bot_turn, rand, move);
}

fn backMove(current_node: *Node, score: i8) void {
    if (current_node.is_boot_node)
        current_node.points += score
    else
        current_node.points -= score;

    current_node.visits += 1;
    if (current_node.parrent_node == null) return;
    backMove(current_node.parrent_node.?, score);
}

fn createNewNodes(allocator: std.mem.Allocator, root_node: *Node) !void {
    const legal_moves = board.getLegalMoves(root_node.pices, root_node.parrent_node.?.move);
    const legal_moves_amount = legal_moves[81];
    if (legal_moves_amount == 0) return;

    var x: usize = 0;
    while (legal_moves_amount > x) : (x += 1) {
        var child = try allocator.create(Node);

        child.* = .{
            .parrent_node = root_node,
            .is_boot_node = !root_node.is_boot_node,
            .move = legal_moves[x],
            .pices = root_node.pices,
            .nodes_under = &.{},
        };
        const nodeMove: board.Cell = if (root_node.is_boot_node) board.Cell.CROSS else board.Cell.DOT;
        child.pices[legal_moves[x]] = nodeMove;

        root_node.nodes_under[x] = child;
    }
}

fn ucb1(points: i32, visits: i32, total_visits: i32) f64 {
    if (visits == 0) return std.math.inf(f64);
    const avg = @as(f64, @floatFromInt(points)) / @as(f64, @floatFromInt(visits));
    const exploration = 1.41 * @sqrt(@log(@as(f64, @floatFromInt(total_visits))) / @as(f64, @floatFromInt(visits))); // højre c højre udforsk
    return avg + exploration;
}
pub fn pickStep(current_node: *Node) usize {
    var index: usize = 0;
    var biggest_val: i32 = -1;
    for (current_node.nodes_under, 0..) |value, i| {
        if (value != null and value.?.visits > biggest_val) {
            index = i;
            biggest_val = value.?.visits;
        }
    }
    return index;
}
