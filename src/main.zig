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
    board: StdVector,
    turn: i32,
    current: i16,
};

const Move = extern struct {
    sub: i32,
    spot: i32,
};

var is_first_time: bool = true;

const threads_amount: usize = 1;

export fn libmcts_bot(boardstate: *const RawBoardstate, _: *i32) Move {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const backing_allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(backing_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var root_nodes: std.ArrayList(Node) = .empty;

    var x: usize = 0;
    while (x < threads_amount) : (x += 1) {
        root_nodes.append(allocator, .{
            .parrent_node = null,
            .pices = rawToBoard(boardstate),
            .is_boot_node = false,
            .nodes_under = &.{},
        }) catch {};
    }

    if (boardstate.turn == 1) {
        mcts.bot_piece = board.Cell.CROSS;
        mcts.opponent_piece = board.Cell.DOT;
    } else if (boardstate.turn == -1) {
        mcts.bot_piece = board.Cell.DOT;
        mcts.opponent_piece = board.Cell.CROSS;
    }

    std.debug.print("__{}__\n", .{boardstate.turn});

    //const start = std.time.milliTimestamp();

    var pool: std.Thread.Pool = undefined;
    pool.init(.{ .allocator = gpa.allocator(), .n_jobs = threads_amount - 1 }) catch unreachable;
    defer pool.deinit();

    var arenas: [threads_amount]std.heap.ArenaAllocator = undefined;
    for (&arenas) |*a| {
        a.* = std.heap.ArenaAllocator.init(gpa.allocator());
    }
    defer for (&arenas) |*a| {
        a.deinit();
    };

    const state: RawBoardstate = boardstate.*;
    var wg: std.Thread.WaitGroup = .{};
    for (0..threads_amount) |value| {
        const alloc = arenas[value].allocator();
        pool.spawnWg(&wg, sim, .{ &root_nodes.items[value], state, alloc });
    }

    pool.waitAndWork(&wg);

    var root_node: Node = .{
        .parrent_node = null,
        .pices = root_nodes.items[0].pices,
        .is_boot_node = false,
        .nodes_under = root_nodes.items[0].nodes_under,
        .points = root_nodes.items[0].points,
        .visits = root_nodes.items[0].visits,
    };

    for (root_nodes.items[1..]) |value| {
        root_node.points += value.points;
        root_node.visits += value.visits;
        for (root_node.nodes_under, 0..) |nodes_under, v| {
            nodes_under.?.visits += value.nodes_under[v].?.visits;
            nodes_under.?.points += value.nodes_under[v].?.points;
        }
    }

    std.debug.print("TOTAL LITS {}\n", .{root_node.visits});

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

    // for (0..threads_amount) |value| local_arenas[value].deinit();
    return .{
        .sub = best_sub,
        .spot = move,
    };
}

fn sim(root_node: *Node, boardstate: RawBoardstate, allocator: std.mem.Allocator) void {
    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    const rand = prng.random();

    // var local_arenas = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //
    // const local_allocator = local_arenas.allocator();

    //const start = std.time.milliTimestamp();
    while (root_node.visits < 1000000) { //(std.time.milliTimestamp() - start < 500) {
        mcts.selection(root_node, allocator, rand, boardstate.current) catch unreachable;
    }
}

fn getRawCell(raw: *const RawBoardstate, row: usize, col: usize) i32 {
    const inner_vectors = @as([*]StdVector, @ptrCast(@alignCast(raw.board.ptr)));
    const row_vec = inner_vectors[row];
    const pieces = @as([*]i32, @ptrCast(@alignCast(row_vec.ptr)));
    return pieces[col];
}

const Data = struct {
    pices: [81]i2 = [_]i2{0} ** 81,
    estimate: f32 = 0,
    sub_board: i16 = 0,
    turn: i8 = 0,
};

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

fn createRandomBoard() Data {
    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    const random = prng.random();

    const start_turn: i16 = if (random.boolean()) 1 else -1;
    var boardstate: RawBoardstate = .{ .current = 0, .board = undefined, .turn = start_turn };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const backing_allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(backing_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    //var root_node: board.Node = .{};

    var root_node: board.Node = .{
        .parrent_node = null,
        //.pices = rawToBoard(&boardstate),
        .is_boot_node = false,
        .nodes_under = &.{},
    };

    if (boardstate.turn == 1) {
        mcts.bot_piece = board.Cell.CROSS;
        mcts.opponent_piece = board.Cell.DOT;
    } else if (boardstate.turn == -1) {
        mcts.bot_piece = board.Cell.DOT;
        mcts.opponent_piece = board.Cell.CROSS;
    }

    while (!createRandomBoardHelper(
        &root_node,
        root_node.is_boot_node,
        &boardstate,
    )) {}

    sim(&root_node, boardstate, allocator);

    const estimate = @as(f32, @floatFromInt(root_node.points)) /
        @as(f32, @floatFromInt(root_node.visits));
    var data: Data = .{};

    data.pices = convert(root_node.pices);
    data.estimate = estimate;
    data.sub_board = boardstate.current;
    data.turn = @intCast(boardstate.turn);

    return data;
}

fn convert(pice: [81]board.Cell) [81]i2 {
    var out: [81]i2 = undefined;

    for (pice, 0..) |p, i| {
        out[i] = @intCast(@intFromEnum(p));
    }

    return out;
}

fn createRandomBoardHelper(root_node: *board.Node, is_bot_turn: bool, state: *RawBoardstate) bool //finder lige et bedre navn senere ish
{
    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    const rand = prng.random();

    // var prng = std.rand.DefaultPrng.init(0);
    // const random = prng.random();
    const randomMoves = rand.intRangeAtMost(u8, 1, 70);

    var new_board = root_node.pices;
    var next_current = state.current;

    var is_bot = is_bot_turn;

    var x: usize = 0;
    while (x < randomMoves) : (x += 1) {
        const legal_moves =
            board.getLegalMoves(&new_board, next_current);
        const legal_moves_amount = legal_moves[81];

        if (legal_moves_amount == 0) return false;

        const value = rand.intRangeLessThan(usize, 0, legal_moves_amount);
        const move = legal_moves[value];

        if (is_bot) {
            new_board[move] = mcts.bot_piece;
        } else {
            new_board[move] = mcts.opponent_piece;
        }

        is_bot = !is_bot;
        next_current = @intCast(board.NEXT_SUBBOARD[move]);
    }

    root_node.pices = new_board;
    state.current = next_current;
    if (is_bot != is_bot_turn) state.turn = @intFromBool(is_bot);
    return true;
}

fn createDataSet() !void {
    //const allocator = std.heap.page_allocator;

    const cwd = std.fs.cwd();

    var file = cwd.openFile("data.csv", .{
        .mode = .read_write,
    }) catch |err| switch (err) {
        error.FileNotFound => try cwd.createFile("data.csv", .{
            .read = true,
            .truncate = false,
        }),
        else => return err,
    };
    defer file.close();

    const stat = try file.stat();
    try file.seekFromEnd(0);

    var buffer: [1024]u8 = undefined;
    var file_writer = file.writer(&buffer);
    const writer = &file_writer.interface;
    if (stat.size == 0) {
        try writer.writeAll("pices,sub_board,turn,est\n");
    }

    std.debug.print("-----start-----\n", .{});
    while (true) {
        const data = createRandomBoard();
        try writer.print("{any},{d},{d},{d}\n", .{ data.pices, data.sub_board, data.turn, data.estimate });
        try writer.flush();
        std.debug.print("______nezt_____", .{});
    }
}

pub fn main() !void {
    try createDataSet();
}
