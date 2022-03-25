const c = @import("client").c;

/// Loads a BMP image from memory.
pub fn loadFromMem(memory: []const u8) !*c.SDL_Surface {
    const len = @intCast(c_int, memory.len);
    var buffer = c.SDL_RWFromConstMem(@ptrCast(*const c_void, memory), len);
    const image = c.SDL_LoadBMP_RW(buffer, 0);
    if (image == 0) return error.ImageNotLoaded;
    return image;
}
