const std = @import("std");

const EXPECTED_LENGTH = 4545;
const START_POINT: u8 = 50;
const FROM: u8 = 0;
const TO: u8 = 99;

pub fn main(init: std.process.Init) !void { 
    const io = init.io;
    const alloc = std.heap.page_allocator;
    
    const owned = try OpenAsOwnedSlice(io, "input.txt", &alloc);
    // std.debug.print("{any}", .{EXPECTED_LENGTH == owned.len});
    // std.debug.print("{any}", .{owned});

    const state = OpenTheLock2(owned, null);

    std.debug.print("{any}\n", .{state.count});
}

test "OpenTheLockPart1Test" {
    const no_wrap_seq= [_]i16{10};
    const no_wrap = OpenTheLock1(&no_wrap_seq, 50);
    try std.testing.expect(no_wrap.pos == 60);
    try std.testing.expect(no_wrap.count == 0);

    const exact_upper_seq = [_]i16{9};
    const exact_upper = OpenTheLock1(&exact_upper_seq, 90);
    try std.testing.expect(exact_upper.pos == 99);
    try std.testing.expect(exact_upper.count == 0);
    
    const cross_upper_by_one_seq = [_]i16{1};
    const cross_upper_by_one = OpenTheLock1(&cross_upper_by_one_seq, 99);
    try std.testing.expect(cross_upper_by_one.pos == 0);
    try std.testing.expect(cross_upper_by_one.count == 1);

    const cross_upper_by_many_seq = [_]i16{10};
    const cross_upper_by_many = OpenTheLock1(&cross_upper_by_many_seq, 95);
    try std.testing.expect(cross_upper_by_many.pos == 5);
    try std.testing.expect(cross_upper_by_many.count == 0);


    const exact_lower_seq = [_]i16{-10};
    const exact_lower = OpenTheLock1(&exact_lower_seq, 10);
    try std.testing.expect(exact_lower.pos == 0);
    try std.testing.expect(exact_lower.count == 1);

    const cross_lower_by_one_seq = [_]i16{-1};
    const cross_lower_by_one = OpenTheLock1(&cross_lower_by_one_seq, 0);
    try std.testing.expect(cross_lower_by_one.pos == 99);
    try std.testing.expect(cross_lower_by_one.count == 0);


    const back_then_back_again_seq = [_]i16{-1, -1};
    const back_then_back_again = OpenTheLock1(&back_then_back_again_seq, 0);
    try std.testing.expect(back_then_back_again.pos == 98);
    try std.testing.expect(back_then_back_again.count == 0);

    const back_around_seq = [_]i16{-100, -1};
    const back_around = OpenTheLock1(&back_around_seq, 50);
    try std.testing.expect(back_around.pos == 49);
    try std.testing.expect(back_around.count == 0);
}

// 0 - 99 
// click noise on each
// rotary
// overflow -> 99 + 1 = 0 and 0 - 1 = 99
// L = negative, R = positive
// Starts at 50
//
// Count how many times we finish on 0 exactly
pub fn OpenTheLock1(sequence: []i16, start_point: ?u8) struct {count: u32, pos: i16} {
    const SIZE: i16 = TO - FROM + 1;

    var position: i16 = if (start_point == null) START_POINT else @intCast(start_point.?);
    var zero_count: u32 = 0;

    for (sequence) |step| {
        position = @mod(position + step, SIZE);

        if (position == 0) {
            zero_count += 1;
        }
    }

    return .{.count=zero_count, .pos=position};
}

// Same but anytime it passes 0 
pub fn OpenTheLock2(sequence: []i16, start_point: ?u8) struct {count: u32, pos: i16} {
    const SIZE: i16 = TO - FROM + 1;

    var position: i16 = if (start_point == null) START_POINT else @intCast(start_point.?);
    var zero_count: u32 = 0;

    for (sequence) |step| {
        std.debug.print("position={d}, step={d}, div={d}\n", .{position, step, @divTrunc(position + step, SIZE)});
        
        var passed_zero: u32 = 0;
        const abs_step = @abs(step);
        const distance_from_zero = if (position == 0)
            SIZE
        else if (step > 0) 
            SIZE - position
        else
            position;
        
        if (abs_step >= distance_from_zero) {
            passed_zero = 1 + @divFloor(
                abs_step - @abs(distance_from_zero),
                SIZE,
            );
        }

        position = @mod(position + step, SIZE);
        
        zero_count += passed_zero;
    }

    return .{.count=zero_count, .pos=position};
}


pub fn OpenAsOwnedSlice(io: std.Io, file_path: []const u8, allocator: *const std.mem.Allocator) ![]i16 {
    const dir = std.Io.Dir.cwd();
    const file = try dir.openFile(io, file_path, .{});

    var list: std.ArrayList(i16) = .empty;
    defer list.deinit(allocator.*);
    
    var buffer: [4096]u8 = undefined;
    var file_reader = file.reader(io, &buffer);
    var reader = &file_reader.interface;

    while (reader.takeDelimiter('\n')) |line| {
        if (line == null) break;

        const trimmed = std.mem.trimEnd(u8, line.?, "\r");
        const negative: bool = trimmed[0] == 'L'; 
        var as_integer = try std.fmt.parseInt(i16, trimmed[1 ..], 10);
        
        if (negative) { as_integer *= -1; }
        
        try list.append(allocator.*, as_integer);
    } else |err| switch (err) {
        else => return err,
    }

    return list.toOwnedSlice(allocator.*);
}

fn absSigned(comptime T: type, x: T) T {
    return if (x < 0) -x else x;
}
