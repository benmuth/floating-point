const rl = @import("raylib");
const std = @import("std");

window_width: i32,
window_height: i32,

number: f16,
number_text: [:0]u8,

bit_repr: u16,

sign: u1,
exponent: u5,
mantissa: u10,

fba: std.heap.FixedBufferAllocator,
allocator: std.mem.Allocator,

buf: []u8,

cursor_pos: u32,

is_text_focused: bool,

text_rect: rl.Rectangle,

number_lines: []NumberLine,

pub const NumberLine = struct {
    marker: OffsetMarker,
    start_x: i32,
    end_x: i32,
    y_pos: i32,
    lower_bound: f32,
    upper_bound: f32,
    normalized_offset: f32,

    pub const lines = enum {
        full,
        window,
    };

    pub fn init(self: *NumberLine, window_width: i32, y_pos: i32, lower_bound: f32, upper_bound: f32, normalized_offset: f32) void {
        const line_margin_ratio = 6;
        self.start_x = @divTrunc(window_width, line_margin_ratio);
        self.end_x = self.start_x * (line_margin_ratio - 1);
        self.y_pos = y_pos;
        self.lower_bound = lower_bound;
        self.upper_bound = upper_bound;
        self.normalized_offset = normalized_offset;

        self.marker = OffsetMarker.init();
    }
};

const OffsetMarker = struct {
    is_moving: bool = false,
    size: i32 = 20,

    fn init() OffsetMarker {
        return .{};
    }
};
