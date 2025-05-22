const std = @import("std");
const rl = @import("raylib");
const State = @import("state.zig");
const NumberLine = State.NumberLine;

const fp_number = std.math.pi * 2;

// fp16 bit representation
// 0 1    6               16
// ┌─┬────┬────────────────┐
// │S│ E  │        M       │
// └─┴────┴────────────────┘

export fn init(opaque_state: *anyopaque, window_width: i32, window_height: i32, buf: *[4096]u8) callconv(.c) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));
    state.fba = std.heap.FixedBufferAllocator.init(buf[0..]);
    state.allocator = state.fba.allocator();

    state.buf = state.allocator.alloc(u8, 1024) catch @panic("Failed to allocate");

    // window
    state.window_width = window_width;
    state.window_height = window_height;

    // main number
    state.number = fp_number;
    state.number_text = std.fmt.bufPrintZ(buf, "{d}", .{state.number}) catch @panic("Failed to render number text");

    // text editing
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

    // components
    state.bit_repr = @bitCast(state.number);

    state.sign = (@as(u1, @truncate((state.bit_repr >> 15) & 0b1)));
    state.exponent = @as(u5, @truncate((state.bit_repr >> 10) & 0b11111));
    state.mantissa = @as(u10, @truncate(state.bit_repr & 0b1111111111));

    // number lines
    state.number_lines = state.allocator.alloc(NumberLine, std.meta.fields(NumberLine.lines).len) catch @panic("Failed to allocate");

    // full line
    const normalized_fp_value: f128 = (@as(f128, @floatCast(std.math.floatMax(f16))) + @as(f128, @floatCast(state.number))) / (2 * @as(f128, @floatCast(std.math.floatMax(f16))));
    state.number_lines[@intFromEnum(NumberLine.lines.full)].init(
        window_width,
        500,
        -std.math.floatMax(f16),
        std.math.floatMax(f16),
        @floatCast(normalized_fp_value),
    );

    // numeric bounds for window line
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

    const mantissa_float: f16 = @floatFromInt(state.mantissa);
    const normalized_mantissa = mantissa_float / std.math.pow(f32, 2, 10);

    // window line
    state.number_lines[@intFromEnum(NumberLine.lines.window)].init(
        window_width,
        state.window_height - 200,
        lower_bound,
        upper_bound,
        normalized_mantissa,
    );
}

const tau_button_rect: rl.Rectangle = .{ .x = 20, .y = 20, .width = 50, .height = 50 };

export fn update(opaque_state: *anyopaque) callconv(.c) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    // tau button handling
    if (rl.isMouseButtonReleased(rl.MouseButton.left) and rl.checkCollisionPointRec(rl.getMousePosition(), tau_button_rect)) {
        state.number = fp_number;
        state.number_text = std.fmt.allocPrintZ(state.allocator, "{d}", .{state.number}) catch @panic("Failed to render number text");

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
            if (is_digit_or_period_or_dash and state.cursor_pos < state.buf.len) {
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

    // marker offset for full line
    const numerator = @as(f128, @floatCast(std.math.floatMax(f16))) + @as(f128, @floatCast(state.number));
    const denominator = 2 * @as(f128, @floatCast(std.math.floatMax(f16)));
    state.number_lines[@intFromEnum(NumberLine.lines.full)].normalized_offset = @floatCast(numerator / denominator);

    // marker offset for window line
    state.number_lines[@intFromEnum(NumberLine.lines.window)].normalized_offset = @as(f16, @floatFromInt(state.mantissa)) / std.math.pow(f32, 2, 10);

    // numeric bounds for window line
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

    state.number_lines[@intFromEnum(NumberLine.lines.window)].lower_bound = lower_bound;
    state.number_lines[@intFromEnum(NumberLine.lines.window)].upper_bound = upper_bound;
}

// TODO: this should probably recompute more state
export fn reload(opaque_state: *anyopaque) callconv(.c) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    state.number_text = std.fmt.bufPrintZ(state.buf, "{d}", .{state.number}) catch @panic(
        "Failed to render number text",
    );

    state.text_rect.y = @as(f32, @floatFromInt(@divTrunc(state.window_height, 6)));
}

export fn draw(opaque_state: *anyopaque) callconv(.c) void {
    const state: *State = @ptrCast(@alignCast(opaque_state));

    var arena = std.heap.ArenaAllocator.init(state.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

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
    const full_number_text = std.fmt.allocPrintZ(
        allocator,
        "{d:0<10}",
        .{state.number},
    ) catch @panic("Failed to render full number");

    rl.drawText(
        full_number_text,
        @divTrunc(state.window_width, 2) - 100,
        @as(i32, @intFromFloat(state.text_rect.y)) + 100,
        @intFromFloat(@divTrunc(state.text_rect.height, 2)),
        rl.Color.black,
    );

    // number components
    const sign_text = std.fmt.allocPrintZ(
        allocator,
        "\tsign\t\nbinary: {b: <1}\ndecimal: {d}",
        .{ state.sign, state.sign },
    ) catch @panic("Failed to render component");

    const exp_text = std.fmt.allocPrintZ(
        allocator,
        "\texponent\t\nbinary: {b: <5}\ndecimal: {d}",
        .{ state.exponent, state.exponent },
    ) catch @panic("Failed to render component");

    const man_text = std.fmt.allocPrintZ(
        allocator,
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
    var formula_text: [:0]const u8 = undefined;
    if (state.exponent == 0 and state.mantissa != 0) {
        formula_text = std.fmt.allocPrintZ(
            allocator,
            "window (exponent) formula (subnormal): 2^126",
            .{},
        ) catch @panic("Failed to render formula");
    } else {
        formula_text = std.fmt.allocPrintZ(
            allocator,
            "window (exponent) formula (normal): 2^({d}-15)\n",
            .{state.exponent},
        ) catch @panic("Failed to render formula");
    }
    rl.drawText(
        formula_text,
        @divTrunc(state.window_width, component_text_spacing) * 2 - 125,
        component_text_y_pos + 120,
        component_text_size,
        rl.Color.black,
    );

    // full number line
    drawNumberLine(state, 0, allocator);

    // window number line
    drawNumberLine(state, 1, allocator);

    // tau button
    rl.drawRectangleRec(tau_button_rect, rl.Color.light_gray);
    rl.drawText("\u{03c4}", 35, 30, 30, rl.Color.black);

    rl.endDrawing();
}

fn drawNumberLine(state: *State, line_index: usize, arena: std.mem.Allocator) void {
    const line = state.number_lines[line_index];

    rl.drawLine(line.start_x, line.y_pos, line.end_x, line.y_pos, rl.Color.black);

    // numeric bounds
    const lower_bound_text = std.fmt.allocPrintZ(
        arena,
        "{d}",
        .{line.lower_bound},
    ) catch @panic("failed to render lower bound");

    const upper_bound_text = std.fmt.allocPrintZ(
        arena,
        "{d}",
        .{line.upper_bound},
    ) catch @panic("failed to render upper bound");

    rl.drawText(lower_bound_text, line.start_x, line.y_pos - 20, 20, rl.Color.black);
    rl.drawText(upper_bound_text, line.end_x, line.y_pos - 20, 20, rl.Color.black);

    // offset marker
    drawOffsetMarker(state, line.start_x, line.end_x, line.y_pos, state.number_lines[line_index].normalized_offset);
}

fn drawOffsetMarker(state: *State, line_start: i32, line_end: i32, height: i32, normalized_offset: f32) void {
    _ = state;
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

    // dragging offset marker
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
