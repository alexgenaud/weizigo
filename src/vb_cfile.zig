// vb_cfile.zig — minimal file I/O via libc, avoids Zig 0.16 Io/Dir API flux.
// Used by verify_battery.zig for artifact loading and output.
const std = @import("std");

/// Read entire file into allocated buffer. Returns bytes or error.
pub fn readFileAlloc(gpa: std.mem.Allocator, path: []const u8, max_size: usize) ![]u8 {
    const path_z = try gpa.dupeZ(u8, path);
    defer gpa.free(path_z);
    const f = std.c.fopen(path_z.ptr, "rb");
    if (f == null) return error.FileNotFound;
    defer _ = std.c.fclose(f);

    _ = std.c.fseek(f, 0, std.c.SEEK.END);
    const size = std.c.ftell(f);
    if (size < 0) return error.FileNotFound;
    if (@as(usize, @intCast(size)) > max_size) return error.FileTooBig;
    _ = std.c.fseek(f, 0, std.c.SEEK.SET);

    const buf = try gpa.alloc(u8, @intCast(size));
    errdefer gpa.free(buf);
    const nread = std.c.fread(buf.ptr, 1, buf.len, f);
    if (nread != buf.len) return error.ReadError;
    return buf;
}

/// Write data to a file (overwrite). Returns void or error.
pub fn writeFile(path: []const u8, data: []const u8) !void {
    const path_z = try std.heap.page_allocator.dupeZ(u8, path);
    defer std.heap.page_allocator.free(path_z);
    const f = std.c.fopen(path_z.ptr, "wb");
    if (f == null) return error.FileNotFound;
    defer _ = std.c.fclose(f);

    const nwritten = std.c.fwrite(data.ptr, 1, data.len, f);
    if (nwritten != data.len) return error.WriteError;
}

/// Get stdout writer using libc stdout.
pub fn stdoutWriter() FileWriter {
    return FileWriter{ .f = std.c.stdout };
}

/// Get stderr writer using libc stderr.
pub fn stderrWriter() FileWriter {
    return FileWriter{ .f = std.c.stderr };
}

pub const FileWriter = struct {
    f: ?*std.c.FILE,

    pub fn write(self: FileWriter, bytes: []const u8) !usize {
        const n = std.c.fwrite(bytes.ptr, 1, bytes.len, self.f);
        return n;
    }

    pub fn writeByte(self: FileWriter, byte: u8) !void {
        _ = std.c.fputc(@intCast(byte), self.f);
    }

    pub fn print(self: FileWriter, comptime fmt: []const u8, args: anytype) !void {
        const buf = try std.fmt.allocPrint(std.heap.page_allocator, fmt, args);
        defer std.heap.page_allocator.free(buf);
        _ = try self.write(buf);
    }
};
