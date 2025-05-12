const std = @import("std");
const rl = @import("raylib");

const window_width = 800;
const window_height = 600;

pub fn main() void {
    rl.initWindow(window_width, window_height, "floating point");

    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        rl.clearBackground(rl.Color.black);

        rl.beginDrawing();
        defer rl.endDrawing();
    }

    defer rl.closeWindow();
}
