const std = @import("std");
const c = @import("c");

pub fn interpretEvent(event: c.SDL_Event) ?c.union_SDL_Event {
    return switch (@intToEnum(c.SDL_EventType, @intCast(c_int, event.type))) {
        .SDL_QUIT => event.quit,
        .SDL_APP_WILLENTERBACKGROUND => @panic("will enter bg\n"),
        .SDL_APP_DIDENTERBACKGROUND => @panic("did enter bg\n"),
        .SDL_APP_WILLENTERFOREGROUND => @panic("will enter fg\n"),
        .SDL_APP_DIDENTERFOREGROUND => @panic("did enter fg\n"),
        .SDL_WINDOWEVENT => event.window,
        .SDL_SYSWMEVENT => @panic("sys wm event\n"),
        .SDL_KEYDOWN => event.key,
        .SDL_KEYUP => event.key,
        .SDL_TEXTEDITING => event.edit,
        .SDL_TEXTINPUT => event.text,
        .SDL_MOUSEMOTION => event.motion,
        .SDL_MOUSEBUTTONDOWN => event.button,
        .SDL_MOUSEBUTTONUP => event.button,
        .SDL_MOUSEWHEEL => event.wheel,
        .SDL_JOYAXISMOTION => event.jaxis,
        .SDL_JOYBALLMOTION => event.jball,
        .SDL_JOYHATMOTION => event.jhat,
        .SDL_JOYBUTTONDOWN => event.jbutton,
        .SDL_JOYBUTTONUP => event.jbutton,
        .SDL_JOYDEVICEADDED => event.jdevice,
        .SDL_JOYDEVICEREMOVED => event.jdevice,
        .SDL_CONTROLLERAXISMOTION => event.caxis,
        .SDL_CONTROLLERBUTTONDOWN => event.cbutton,
        .SDL_CONTROLLERBUTTONUP => event.cbutton,
        .SDL_CONTROLLERDEVICEADDED => event.cdevice,
        .SDL_CONTROLLERDEVICEREMOVED => event.cdevice,
        .SDL_CONTROLLERDEVICEREMAPPED => event.cdevice,
        .SDL_FINGERDOWN => event.tfinger,
        .SDL_FINGERUP => event.tfinger,
        .SDL_FINGERMOTION => event.tfinger,
        .SDL_DOLLARGESTURE => event.dgesture,
        .SDL_DOLLARRECORD => event.dgesture,
        .SDL_MULTIGESTURE => event.mgesture,
        .SDL_DROPFILE => event.drop,
        .SDL_DROPTEXT => event.drop,
        .SDL_DROPBEGIN => event.drop,
        .SDL_DROPCOMPLETE => event.drop,
        else => null,
    };
}