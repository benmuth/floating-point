const std = @import("std");
const rl = @import("raylib");
const State = @import("state.zig");

const fp_number = std.math.pi * 2;

export fn init(state: *State, width: i32, height: i32, buf: *[1024]u8) void {
    state.window_width = width;
    state.window_height = height;
    state.number = fp_number;
    state.number_text = std.fmt.bufPrintZ(buf, "{d}", .{state.number}) catch @panic("Failed to render number text");
    state.buf = buf;
    state.cursor_pos = 0;
    state.is_text_focused = false;
    const text_width = 50;
    const text_height = 20;
    state.text_rect = .{
        .x = @as(f32, @floatFromInt(@divTrunc(state.window_width, 5))) * 2.5,
        .y = @as(f32, @floatFromInt(@divTrunc(state.window_height, 6))) * 3,
        .width = text_width,
        .height = text_height,
    };
}

export fn update(opaque_state: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
        if (rl.checkCollisionPointRec(rl.getMousePosition(), state.text_rect)) {
            state.is_text_focused = true;
        } else {
            state.is_text_focused = false;
        }
    }

    if (state.is_text_focused) {
        var char = rl.getCharPressed();
        // TODO: only allow digits to be entered
        while (char > 0) {
            std.debug.print("char: {d}\n", .{char});
            // NOTE: Only allow numbers
            const is_digit_or_period_or_dash = (char >= 48 and char <= 57) or char == 46;
            if (is_digit_or_period_or_dash and state.cursor_pos < state.number_text.len) {
                state.number_text[state.cursor_pos] = @intCast(char);
                state.cursor_pos += 1;
                state.number_text[state.cursor_pos] = 0; // Add null terminator at the end of the string.
                std.debug.print("cursor: {d}\n", .{state.cursor_pos});
                std.debug.print("number: {s}\n", .{state.number_text});
            }

            char = rl.getCharPressed(); // Check next character in the queue
        }

        if (rl.isKeyPressed(rl.KeyboardKey.backspace)) {
            state.cursor_pos -|= 1;
            state.number_text[state.cursor_pos] = 0;
        }

        const cleaned_number = std.mem.span(state.number_text.ptr);
        // HACK: deal with an empty string better
        if (cleaned_number.len == 0) {
            state.number = 0;
        } else {
            state.number = std.fmt.parseFloat(f16, cleaned_number) catch @panic("couldn't parse inputted float");
        }
    }
}

export fn reload(opaque_state: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    state.number = fp_number;
    state.number_text = std.fmt.bufPrintZ(state.buf, "{d}", .{state.number}) catch @panic(
        "Failed to render number text",
    );
    state.text_rect.x = @as(f32, @floatFromInt(@divTrunc(state.window_width, 5))) * 2.5;
    state.text_rect.y = @as(f32, @floatFromInt(@divTrunc(state.window_height, 6)));
}

export fn draw(opaque_state: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    rl.beginDrawing();
    rl.clearBackground(rl.Color.white);

    // text input
    const text_box_color = if (state.is_text_focused) rl.Color.light_gray else rl.Color.gray;
    rl.drawRectangleRec(state.text_rect, text_box_color);

    // floating point number
    rl.drawText(state.number_text, @intFromFloat(state.text_rect.x), @intFromFloat(state.text_rect.y), 20, rl.Color.black);

    // number line
    const line_margin_ratio = 6;
    const line_start = @divTrunc(state.window_width, line_margin_ratio);
    const line_end = line_start * (line_margin_ratio - 1);
    const line_height = state.window_height - 100;
    rl.drawLine(line_start, line_height, line_end, line_height, rl.Color.black);

    rl.endDrawing();
}
