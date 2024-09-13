const Str = @import("strings.zig").Str;
const DPrint = @import("std").debug.print;

pub fn ShowErrorAtPoint(expr: *Str, loc: u32) void {
    var linestart: u32 = 0;
    var linenum: u32 = 0;
    for (0..loc) |i| {
        const char = expr.backer[i];
        if (char == '\n' or char == '\r') {
            linestart = @intCast(i+1);
        }
        linenum += @intFromBool(char == '\n');
    }
    var lineend = linestart;
    while (lineend < expr.backer.len and !(expr.backer[lineend] == '\r' or expr.backer[lineend] == '\n')) : (lineend += 1){}
    DPrint("Error on line: {}, col: {}\n\t{s}\n", .{linenum+1, loc-linestart+1, expr.backer[linestart..lineend]});
    const spad = (" " ** 256)[0..loc-linestart];
    DPrint("\t{s}^\n", .{spad});
}