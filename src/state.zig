const rl = @import("raylib");

window_width: i32,
window_height: i32,

number: f16,
number_text: [:0]u8,

buf: *[1024]u8,

cursor_pos: u32,

is_text_focused: bool,

text_rect: rl.Rectangle,
