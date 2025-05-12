const std = @import("std");
const rl = @import("raylib");

const text: [:0]const u8 = "hello world";

// export fn init(uninitialized_state: *anyopaque, width: f32, height: f32) void {
//     const state: *State = @ptrCast(@alignCast(uninitialized_state));

//     state.window_width = width;
//     state.window_height = height;
// }

export fn init(width: i32, height: i32) *anyopaque {
    const allocator = std.heap.c_allocator;

    const state: *State = allocator.create(State) catch @panic("Failed to create state pointer");

    state.window_width = width;
    state.window_height = height;
    state.text = text;

    return state;
}

export fn update(opaque_state: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    _ = state;
}

export fn reload(opaque_state: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    state.text = text;
}

export fn draw(opaque_state: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    rl.beginDrawing();

    rl.clearBackground(rl.Color.white);

    rl.drawText(state.text, @divTrunc(state.window_width, 2), @divTrunc(state.window_height, 2), 20, rl.Color.black);

    rl.endDrawing();
}

const State = struct {
    window_width: i32,
    window_height: i32,
    text: [:0]const u8,
};
