const std = @import("std");

const stb = @cImport({
    @cInclude("stb_image.h");
    @cInclude("stb_image_resize2.h");
    @cInclude("stb_image_write.h");
});

const Image = struct {
    data: []u8,
    info: Info,

    const Info = struct {
        width: c_int,
        height: c_int,
        channels: c_int,
    };

    pub fn from_filename(filename: [:0]const u8) !Image {
        var x: c_int = undefined;
        var y: c_int = undefined;
        var n: c_int = undefined;
        const data = stb.stbi_load(filename, &x, &y, &n, 0);
        if (data == null) {
            @panic("Failed to load image");
        }
        return Image{
            .data = data[0..@intCast(x * y * n)],
            .info = .{
                .width = x,
                .height = y,
                .channels = n,
            },
        };
    }

    pub fn deinit(self: Image) void {
        stb.stbi_image_free(self.data.ptr);
    }

    pub fn info(self: Image) Info {
        return self.info;
    }

    pub fn resize(self: Image, out_x: c_int, out_y: c_int) !Image {
        const n = self.info.channels;
        const out_data = stb.stbir_resize_uint8_linear(
            self.data.ptr,
            self.info.width,
            self.info.height,
            0,
            null,
            out_x,
            out_y,
            0,
            @intCast(n),
        );
        return Image{
            .data = out_data[0..@intCast(out_x * out_y * n)],
            .info = .{
                .width = out_x,
                .height = out_y,
                .channels = n,
            },
        };
    }

    pub fn write(self: Image, filename: [:0]const u8) !void {
        const result = stb.stbi_write_png(
            filename,
            self.info.width,
            self.info.height,
            self.info.channels,
            self.data.ptr,
            0,
        );
        if (result == 0) {
            return error.void;
        }
    }
};

fn print_usage() !void {
    const stderr = std.io.getStdErr();
    _ = try stderr.write("Usage: image_resize <filename> <width> <height>\n");
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip(); // skip program name

    const filename: [:0]const u8 = args.next() orelse {
        try print_usage();
        return;
    };

    const width: c_int = blk: {
        if (args.next()) |width_str| {
            break :blk try std.fmt.parseInt(c_int, width_str, 10);
        } else {
            try print_usage();
            return;
        }
    };
    const height: c_int = blk: {
        if (args.next()) |height_str| {
            break :blk try std.fmt.parseInt(c_int, height_str, 10);
        } else {
            try print_usage();
            return;
        }
    };

    const image = try Image.from_filename(filename);
    defer image.deinit();

    const resized = try image.resize(width, height);
    defer resized.deinit();

    try resized.write("resized.png");
}
