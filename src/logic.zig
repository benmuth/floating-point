const std = @import("std");
const rl = @import("raylib");
const State = @import("state.zig");

const fp_number = std.math.pi * 2;

const fp_text_buffer_length = 100;

// fp16 bit representation
// 0 1    6               16
// ┌─┬────┬────────────────┐
// │S│ E  │        M       │
// └─┴────┴────────────────┘

export fn init(state: *State, width: i32, height: i32, buf: *[1024]u8) void {
    state.window_width = width;
    state.window_height = height;
    state.number = fp_number;
    state.number_text = std.fmt.bufPrintZ(buf, "{d}", .{state.number}) catch @panic("Failed to render number text");

    state.bit_repr = @bitCast(state.number);

    state.sign = (@as(u1, @truncate((state.bit_repr >> 15) & 0b1)));
    state.exponent = @as(u5, @truncate((state.bit_repr >> 10) & 0b11111));
    state.mantissa = @as(u10, @truncate(state.bit_repr & 0b1111111111));

    state.buf = buf;
    state.cursor_pos = 0;
    state.is_text_focused = false;
    const text_width: f32 = @floatFromInt(state.window_width);
    const text_height = @as(f32, @floatFromInt(@divTrunc(state.window_height, 12)));
    state.text_rect = .{
        .x = 0,
        .y = @as(f32, @floatFromInt(@divTrunc(state.window_height, 6))),
        .width = text_width,
        .height = text_height,
    };
}

const tau_button_rect: rl.Rectangle = .{ .x = 20, .y = 20, .width = 50, .height = 50 };

export fn update(opaque_state: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    // tau button handling
    if (rl.isMouseButtonReleased(rl.MouseButton.left) and rl.checkCollisionPointRec(rl.getMousePosition(), tau_button_rect)) {
        state.number = fp_number;
        state.number_text = std.fmt.bufPrintZ(state.buf, "{d}", .{state.number}) catch @panic("Failed to render number text");

        state.bit_repr = @bitCast(state.number);

        state.sign = (@as(u1, @truncate((state.bit_repr >> 15) & 0b1)));
        state.exponent = @as(u5, @truncate((state.bit_repr >> 10) & 0b11111));
        state.mantissa = @as(u10, @truncate(state.bit_repr & 0b1111111111));
    }

    // Text input focus
    if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
        if (rl.checkCollisionPointRec(rl.getMousePosition(), state.text_rect)) {
            state.is_text_focused = true;
        } else {
            state.is_text_focused = false;
        }
    }

    // Text input handling and number updating
    if (state.is_text_focused) {
        var char = rl.getCharPressed();

        // Handle multiple keys pressed in a single frame
        while (char > 0) {
            // std.debug.print("char: {d}\n", .{char});

            const is_digit_or_period_or_dash = (char >= 48 and char <= 57) or char == 46 or char == 45;
            if (is_digit_or_period_or_dash and state.cursor_pos < fp_text_buffer_length) {
                state.buf[state.cursor_pos] = @intCast(char);
                state.cursor_pos += 1;
                state.buf[state.cursor_pos] = 0; // Add null terminator at the end of the string.
                // std.debug.print("cursor: {d}\n", .{state.cursor_pos});
                // std.debug.print("number: {s}\n", .{state.number_text});
            }

            char = rl.getCharPressed(); // Check next character in the queue
        }

        if (rl.isKeyPressed(rl.KeyboardKey.backspace)) {
            state.cursor_pos -|= 1;
            state.buf[state.cursor_pos] = 0;
        }

        const cleaned_number = std.mem.span(state.number_text.ptr);

        // std.debug.print("cleaned number: {s}\n", .{cleaned_number});
        // std.debug.print("cleaned number: {any}\n", .{cleaned_number});

        // TODO: deal with an empty string better
        if (cleaned_number.len == 0) {
            state.number = 0;
        } else {
            // Handle incomplete/invalid input by skipping analysis
            state.number = std.fmt.parseFloat(f16, cleaned_number) catch return;
        }

        state.bit_repr = @bitCast(state.number);

        state.sign = (@as(u1, @truncate((state.bit_repr >> 15) & 0b1)));
        state.exponent = @as(u5, @truncate((state.bit_repr >> 10) & 0b11111));
        state.mantissa = @as(u10, @truncate(state.bit_repr & 0b1111111111));
    }
}

// TODO: this should probably recompute more state
export fn reload(opaque_state: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    state.number_text = std.fmt.bufPrintZ(state.buf[0..fp_text_buffer_length], "{d}", .{state.number}) catch @panic(
        "Failed to render number text",
    );

    state.text_rect.y = @as(f32, @floatFromInt(@divTrunc(state.window_height, 6)));
}

export fn draw(opaque_state: *anyopaque) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    rl.beginDrawing();
    rl.clearBackground(rl.Color.white);

    // text input box
    const text_box_color = if (state.is_text_focused) rl.Color.ray_white else rl.Color.light_gray;
    rl.drawRectangleRec(state.text_rect, text_box_color);

    // inputted number
    rl.drawText(
        state.number_text,
        @divTrunc(state.window_width, 2) - 100,
        @intFromFloat(state.text_rect.y),
        @intFromFloat(state.text_rect.height),
        rl.Color.black,
    );

    // machine representation of number
    // const full_number_text = std.fmt.bufPrintZ(
    //     state.buf[500..600],
    //     "{d:0<10}",
    //     .{state.number},
    // ) catch @panic("Failed to render full number");

    // rl.drawText(
    //     full_number_text,
    //     @divTrunc(state.window_width, 2) - 100,
    //     @as(i32, @intFromFloat(state.text_rect.y)) + 100,
    //     @intFromFloat(@divTrunc(state.text_rect.height, 2)),
    //     rl.Color.black,
    // );

    // number components
    const sign_text = std.fmt.bufPrintZ(
        state.buf[fp_text_buffer_length .. fp_text_buffer_length + 50],
        "\tsign\t\nbinary: {b: <1}\ndecimal: {d}",
        .{ state.sign, state.sign },
    ) catch @panic("Failed to render component");

    const exp_text = std.fmt.bufPrintZ(
        state.buf[fp_text_buffer_length + 50 .. fp_text_buffer_length + 100],
        "\texponent\t\nbinary: {b: <5}\ndecimal: {d}",
        .{ state.exponent, state.exponent },
    ) catch @panic("Failed to render component");

    const man_text = std.fmt.bufPrintZ(
        state.buf[fp_text_buffer_length + 100 .. fp_text_buffer_length + 200],
        "\tmantissa\t\nbinary: {b: <10}\ndecimal: {d}",
        .{ state.mantissa, state.mantissa },
    ) catch @panic("Failed to render component");

    const component_text_size = 20;
    const component_text_spacing = 4;
    const component_text_y_pos: i32 = @as(i32, @intFromFloat(state.text_rect.y)) + 150;
    rl.drawText(
        sign_text,
        @divTrunc(state.window_width, component_text_spacing),
        component_text_y_pos,
        component_text_size,
        rl.Color.black,
    );
    rl.drawText(
        exp_text,
        @divTrunc(state.window_width, component_text_spacing) * 2,
        component_text_y_pos,
        component_text_size,
        rl.Color.black,
    );
    rl.drawText(
        man_text,
        @divTrunc(state.window_width, component_text_spacing) * 3,
        component_text_y_pos,
        component_text_size,
        rl.Color.black,
    );

    // window formula
    // var formula_text: [:0]const u8 = undefined;
    // if (state.exponent == 0 and state.mantissa != 0) {
    //     formula_text = std.fmt.bufPrintZ(
    //         state.buf[fp_text_buffer_length + 200 .. fp_text_buffer_length + 300],
    //         "window (exponent) formula (subnormal): 2^126",
    //         .{},
    //     ) catch @panic("Failed to render formula");
    // } else {
    //     formula_text = std.fmt.bufPrintZ(
    //         state.buf[fp_text_buffer_length + 200 .. fp_text_buffer_length + 300],
    //         "window (exponent) formula (normal): 2^({d}-15)\n",
    //         .{state.exponent},
    //     ) catch @panic("Failed to render formula");
    // }
    // rl.drawText(
    //     formula_text,
    //     @divTrunc(state.window_width, component_text_spacing) * 2 - 125,
    //     component_text_y_pos + 120,
    //     component_text_size,
    //     rl.Color.black,
    // );

    // numeric bounds
    var lower_bound: f32 = undefined;
    var upper_bound: f32 = undefined;

    if (state.exponent == 0) {
        lower_bound = 0;
        upper_bound = std.math.pow(f32, 2, -14);
    } else {
        lower_bound = std.math.pow(
            f32,
            2,
            (@as(f32, @floatFromInt(state.exponent)) - 15),
        );
        upper_bound = lower_bound * 2;
    }

    // window number line
    const mantissa_float: f16 = @floatFromInt(state.mantissa);
    const normalized_mantissa = mantissa_float / std.math.pow(f32, 2, 10);
    drawNumberLine(
        state,
        state.window_height - 200,
        lower_bound,
        upper_bound,
        normalized_mantissa,
        400,
    );

    // full number line
    const normalized_fp_value: f128 = (@as(f128, @floatCast(std.math.floatMax(f16))) + @as(f128, @floatCast(state.number))) / (2 * @as(f128, @floatCast(std.math.floatMax(f16))));
    drawNumberLine(
        state,
        state.window_height - 300,
        -std.math.floatMax(f16),
        std.math.floatMax(f16),
        @floatCast(normalized_fp_value),
        500,
    );

    // tau button
    rl.drawRectangleRec(tau_button_rect, rl.Color.light_gray);
    rl.drawText("\u{03c4}", 35, 30, 30, rl.Color.black);

    rl.endDrawing();
}

fn drawNumberLine(state: *State, height: i32, lower_bound: f32, upper_bound: f32, normalized_offset: f32, buf_offset: usize) void {
    // line
    const line_margin_ratio = 6;
    const line_start = @divTrunc(state.window_width, line_margin_ratio);
    const line_end = line_start * (line_margin_ratio - 1);
    rl.drawLine(line_start, height, line_end, height, rl.Color.black);

    // numeric bounds
    const lower_bound_text = std.fmt.bufPrintZ(
        state.buf[buf_offset .. buf_offset + 50],
        "{d}",
        .{lower_bound},
    ) catch @panic("failed to render lower bound");

    const upper_bound_text = std.fmt.bufPrintZ(
        state.buf[buf_offset + 50 .. buf_offset + 100],
        "{d}",
        .{upper_bound},
    ) catch @panic("failed to render upper bound");

    rl.drawText(lower_bound_text, line_start, height - 20, 20, rl.Color.black);
    rl.drawText(upper_bound_text, line_end, height - 20, 20, rl.Color.black);

    // offset marker
    const line_start_float: f16 = @floatFromInt(line_start);
    const line_end_float: f16 = @floatFromInt(line_end);
    const line_height_float: f16 = @floatFromInt(height);

    const offset_pos = std.math.lerp(
        line_start_float,
        line_end_float,
        normalized_offset,
    );

    const offset_marker_top: rl.Vector2 = .{ .x = offset_pos, .y = line_height_float + 10 };
    const offset_marker_left: rl.Vector2 = .{ .x = offset_pos - 10, .y = line_height_float + 20 };
    const offset_marker_right: rl.Vector2 = .{ .x = offset_pos + 10, .y = line_height_float + 20 };

    rl.drawTriangle(offset_marker_top, offset_marker_left, offset_marker_right, rl.Color.black);

    // // dragging offset marker
    // if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
    //     if (rl.checkCollisionPointTriangle(rl.getMousePosition(), offset_marker_top, offset_marker_left, offset_marker_right)) {
    //         state.is_moving_offset_marker = true;
    //         rl.drawTriangle(offset_marker_top, offset_marker_left, offset_marker_right, rl.Color.red);
    //     }
    //     // rl.drawTriangle(offset_marker_top, offset_marker_left, offset_marker_right, rl.Color.blue);
    // } else {
    //     state.is_moving_offset_marker = false;
    //     rl.drawTriangle(offset_marker_top, offset_marker_left, offset_marker_right, rl.Color.green);
    // }
}
