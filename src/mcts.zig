const board = @import("board.zig");

fn selection(root_node: *Node, allocator: std.mem.Allocator, rand: std.Random) !void {
    try createNewNodes(allocator, root_node);
    var ucb1Val: [9]f64 = .{0} ** 9;
    const bored = root_node.*.bored;
    for (bored, 0..) |cell, i| {
        if (cell == .None) {
            ucb1Val[i] = ucb1(root_node.nodes_under[i].?.*.points, root_node.nodes_under[i].?.*.n, root_node.n);
            // std.debug.print("node points : {}  node visits : {}  parrent node visits {} \n", .{ root_node.nodes_under[i].?.*.points, root_node.nodes_under[i].?.*.n, root_node.n });
            //  std.debug.print("val : {}\n", .{ucb1Val[i]});
        }
    }
    var best_index: usize = 9;
    var max_ucb: f64 = -999999;

    for (ucb1Val, 0..) |value, i| {
        if (bored[i] == .None and value >= max_ucb) {
            max_ucb = value;
            best_index = i;
        }
    }

    if (checkStateFromBored(&root_node.bored) != gameStillGoingVal) {
        const current_score = checkStateFromBored(&root_node.bored);
        backMove(root_node, current_score);
        count_test += 1;
        return;
    }

    if (best_index == 9) unreachable;
    const node = root_node.nodes_under[best_index].?;
    if (node.n != 0) return selection(root_node.nodes_under[best_index].?, allocator, rand);
    if (node.n == 0) {
        simulate(node, rand);
        return;
    }

    unreachable;
    ////std.debug.print("THIS SHOUD NEVER SHOUD", .{});
}

fn simulate(start_node: *Node, rand: std.Random) void {
    // var x_count: u8 = 0;
    // var o_count: u8 = 0;
    // for (start_node.bored) |cell| {
    //     if (cell == .X) x_count += 1;
    //     if (cell == .O) o_count += 1;
    // }
    // const is_bot_turn = (x_count > o_count);
    //
    // if (is_bot_turn == start_node.is_bot) unreachable;
    const score = playOut(start_node.bored, start_node.is_bot, rand);

    backMove(start_node, score);
    return;
}

fn playOut(current_board: [9]Player, is_bot_turn: bool, rand: std.Random) i8 {
    const x = checkStateFromBored(&current_board);
    switch (x) {
        gameStillGoingVal => {},
        else => {
            return x;
        },
    }

    const legal_moves = getLegalMoves(&current_board);
    const legal_moves_amount = legal_moves[9];

    const value = rand.intRangeLessThan(usize, 0, legal_moves_amount);
    const move = legal_moves[value];

    var new_board = current_board;

    if (is_bot_turn) {
        new_board[move] = Player.O;
    } else {
        new_board[move] = Player.X;
    }

    return playOut(new_board, !is_bot_turn, rand);
}

fn backMove(current_node: *Node, score: i8) void {
    if (current_node.is_bot)
        current_node.points += score
    else
        current_node.points -= score;

    current_node.n += 1;
    if (current_node.parrent_node == null) return;
    backMove(current_node.parrent_node.?, score);
}

fn getLegalMoves(board: *const [9]Player) [10]u8 {
    var current_legal_index: u8 = 0;
    var legal_moves: [10]u8 = .{0} ** 10;
    for (board, 0..) |value, i| {
        if (value == .None) {
            legal_moves[@intCast(current_legal_index)] = @intCast(i);
            current_legal_index += 1;
        }
    }
    legal_moves[9] = current_legal_index;
    return legal_moves;
}

fn createNewNodes(allocator: std.mem.Allocator, root_node: *Node) !void {
    for (root_node.nodes_under, 0..) |value, i| {
        if (value != null) continue;

        if (root_node.bored[i] != .None) continue;

        var child_board = root_node.bored;
        const nodeMove: Player = if (root_node.is_bot) .X else .O;
        child_board[i] = nodeMove;

        root_node.nodes_under[i] = try allocator.create(Node);
        root_node.nodes_under[i].?.* = .{
            .parrent_node = root_node,
            .bored = child_board,
            .is_bot = !root_node.is_bot,
        };
        root_node.nodes_under[i].?.parrent_node = root_node;
    }
}

fn ucb1(points: i32, visits: i32, total_visits: i32) f64 {
    if (visits == 0) return std.math.inf(f64);
    const avg = @as(f64, @floatFromInt(points)) / @as(f64, @floatFromInt(visits));
    const exploration = 1.41 * @sqrt(@log(@as(f64, @floatFromInt(total_visits))) / @as(f64, @floatFromInt(visits))); // højre c højre udforsk
    return avg + exploration;
}
