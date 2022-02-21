const std = @import("std");
const c = @import("c");

extern fn SDL_CreateSystemCursor(c_int) *c.SDL_Cursor;
const Cursor = enum(c_int) {
    arrow = c.SDL_SYSTEM_CURSOR_ARROW,
    ibeam = c.SDL_SYSTEM_CURSOR_IBEAM,
    wait = c.SDL_SYSTEM_CURSOR_WAIT,
    crosshair = c.SDL_SYSTEM_CURSOR_CROSSHAIR,
    waitarrow = c.SDL_SYSTEM_CURSOR_WAITARROW,
    size_nwse = c.SDL_SYSTEM_CURSOR_SIZENWSE,
    size_nesw = c.SDL_SYSTEM_CURSOR_SIZENESW,
    size_we = c.SDL_SYSTEM_CURSOR_SIZEWE,
    size_ns = c.SDL_SYSTEM_CURSOR_SIZENS,
    sizeall = c.SDL_SYSTEM_CURSOR_SIZEALL,
    no = c.SDL_SYSTEM_CURSOR_NO,
    hand = c.SDL_SYSTEM_CURSOR_HAND,
};

pub fn createSystemCursor(cursor: Cursor) !*c.SDL_Cursor {
    const result = SDL_CreateSystemCursor(@enumToInt(cursor));
    if (@ptrToInt(result) == 0) {
        c.SDL_Log("Unable to set system cursor: %s", c.SDL_GetError());
        return error.SettingCursorFailed;
    }
    return result;
}
