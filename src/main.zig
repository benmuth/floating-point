const std = @import("std");
const rl = @import("raylib");
const State = @import("state.zig");

const window_width = 1200;
const window_height = 800;

const StatePtr = *anyopaque;

var init: *const fn (state: StatePtr, width: i32, height: i32, buf: *[4096]u8) callconv(.c) void = undefined;
var update: *const fn (state: StatePtr) callconv(.c) void = undefined;
var reload: *const fn (state: StatePtr) callconv(.c) void = undefined;
var draw: *const fn (state: StatePtr) callconv(.c) void = undefined;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try loadLogicDll();

    var buffer: [4096]u8 = undefined;

    const state = try allocator.create(State);

    init(state, window_width, window_height, &buffer);

    rl.initWindow(window_width, window_height, "floating point");
    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(rl.KeyboardKey.backslash)) {
            try unloadLogicDll();
            try recompileLogicDll(allocator);
            try loadLogicDll();
            reload(state);
        }
        update(state);
        draw(state);
    }

    defer rl.closeWindow();
}

var editor_dyn_lib: ?std.DynLib = null;

fn loadLogicDll() !void {
    if (editor_dyn_lib != null) return error.AlreadyLoaded;

    var dyn_lib = std.DynLib.open("zig-out/lib/liblogic.dylib") catch {
        return error.OpenFail;
    };

    editor_dyn_lib = dyn_lib;

    init = dyn_lib.lookup(@TypeOf(init), "init") orelse return error.lookupFail;
    reload = dyn_lib.lookup(@TypeOf(reload), "reload") orelse return error.lookupFail;
    update = dyn_lib.lookup(@TypeOf(update), "update") orelse return error.lookupFail;
    draw = dyn_lib.lookup(@TypeOf(draw), "draw") orelse return error.lookupFail;

    std.debug.print("Loaded dll\n", .{});
}

fn unloadLogicDll() !void {
    if (editor_dyn_lib) |*dyn_lib| {
        dyn_lib.close();
        editor_dyn_lib = null;
    } else {
        return error.AlreadyUnloaded;
    }
}

fn recompileLogicDll(arena: std.mem.Allocator) !void {
    std.debug.print("recompiling...\n", .{});

    const process_args = [_][]const u8{
        "zig",
        "build",
        "-Dlogic_only=true",
    };
    var build_process = std.process.Child.init(&process_args, arena);
    try build_process.spawn();

    // wait() returns a tagged union. If the compilations fails that union
    // will be in the state .{ .Exited = 2 }
    const term = try build_process.wait();
    switch (term) {
        .Exited => |exited| {
            if (exited == 2) return error.RecompileFail;
        },
        else => return,
    }
}
