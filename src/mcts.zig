const std = @import("std");
const board = @import("board.zig");
const Node = board.Node;

pub var bot_piece: board.Cell = undefined;
pub var opponent_piece: board.Cell = undefined;

pub fn selection(root_node: *Node, allocator: std.mem.Allocator, rand: std.Random, current: i16) !void {
    var current_root_node = root_node;
    var current_current = current;

    var best_index: usize = 99;
    var max_ucb: f64 = -999999;
    var ucb1Val: [81]f64 = .{0} ** 81;
    while (true) {
        try createNewNodes(allocator, current_root_node, current_current);

        ucb1Val = .{0} ** 81;

        for (0..current_root_node.nodes_under.len) |x| {
            ucb1Val[x] = ucb1(
                current_root_node.nodes_under[x].?.points,
                current_root_node.nodes_under[x].?.visits,
                current_root_node.visits,
            );
        }

        best_index = 99;
        max_ucb = -999999;

        for (0..current_root_node.nodes_under.len) |value| {
            if (ucb1Val[value] >= max_ucb) {
                max_ucb = ucb1Val[value];
                best_index = value;
            }
        }

        //std.debug.print("index : {}\n", .{best_index});

        if (board.checkState(&current_root_node.pices) != board.STILL_GOING) {
            const current_score = board.checkState(&current_root_node.pices);
            backMove(current_root_node, current_score);
            return;
        }

        if (best_index == 99) unreachable;
        const node = current_root_node.nodes_under[best_index].?;
        const next_current: i16 = @intCast(board.NEXT_SUBBOARD[node.move]);
        if (node.visits != 0) { //return selection(root_node.nodes_under[best_index].?, allocator, rand, next_current);

            current_root_node = current_root_node.nodes_under[best_index].?;
            current_current = next_current;
            continue;
        }
        if (node.visits == 0) {
            simulate(node, rand, next_current);
            return;
        }

        std.debug.print("__NO FUCKED UP ____\n", .{});
        unreachable;
    }
}

fn simulate(start_node: *Node, rand: std.Random, current: i16) void {
    const score =
        playOut(start_node.pices, start_node.is_boot_node, rand, current);
    backMove(start_node, score);
    return;
}

fn playOut(current_board: [81]board.Cell, is_bot_turn: bool, rand: std.Random, current: i16) i8 {
    var new_board = current_board;
    var next_current = current;

    var is_bot = is_bot_turn;

    while (true) {
        const legal_moves =
            board.getLegalMoves(&new_board, next_current);
        const legal_moves_amount = legal_moves[81];

        if (legal_moves_amount == 0) break;

        const value = rand.intRangeLessThan(usize, 0, legal_moves_amount);
        const move = legal_moves[value];

        if (is_bot) {
            new_board[move] = bot_piece;
        } else {
            new_board[move] = opponent_piece;
        }

        is_bot = !is_bot;
        next_current = @intCast(board.NEXT_SUBBOARD[move]);
    }

    const x = board.checkState(&new_board);
    if (x == board.STILL_GOING) unreachable;
    return x;
    //const next_current: i16 = @intCast(board.NEXT_SUBBOARD[move]);
    //  return playOut(new_board, !is_bot_turn, rand, next_current);
}

fn backMove(current_node: *Node, score: i8) void {
    const piece_val: i32 = @intFromEnum(bot_piece);
    if (current_node.is_boot_node)
        current_node.points += score * piece_val
    else
        current_node.points -= score * piece_val;

    current_node.visits += 1;

    if (current_node.parrent_node == null) return;
    backMove(current_node.parrent_node.?, score);
}

pub fn createNewNodes(allocator: std.mem.Allocator, root_node: *Node, current: i16) !void {
    if (root_node.nodes_under.len != 0) return;

    const legal_moves = board.getLegalMoves(&root_node.pices, current);

    const legal_moves_amount = legal_moves[81];
    if (legal_moves_amount == 0) return;

    root_node.nodes_under = try allocator.alloc(?*Node, legal_moves_amount);
    @memset(root_node.nodes_under, null);
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
        //const nodeMove: board.Cell = if (root_node.is_boot_node) board.Cell.CROSS else board.Cell.DOT;
        const nodeMove: board.Cell = if (root_node.is_boot_node) opponent_piece else bot_piece;

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
pub fn pickStep(current_node: *Node) u8 {
    var index: u8 = 0;
    var biggest_val: i32 = -1;
    for (current_node.nodes_under, 0..) |value, i| {
        if (value != null and value.?.visits > biggest_val) {
            index = @intCast(i);
            biggest_val = value.?.visits;
        }
    }
    //std.debug.print("move : {} :\n", .{current_node.nodes_under[index].?.move});
    return index;
}

fn getMoveFromBoards(old: [81]board.Cell, new: [81]board.Cell) u8 {
    for (0..81) |i| {
        if (old[i] != new[i]) {
            return @intCast(i);
        }
    }
    unreachable;
}
