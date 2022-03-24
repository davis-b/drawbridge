usingnamespace @cImport({
    @cInclude("SDL.h");
    // @cInclude("setpixel.c");
    //    @cInclude("SDL2_gfxPrimitives.h");
});
pub extern fn changeColors(width: c_int, height: c_int, colorA: u32, colorB: u32, surf: *SDL_Surface) void;
pub extern fn inverseColors(width: c_int, height: c_int, colorA: u32, colorB: u32, surf: *SDL_Surface) void;
