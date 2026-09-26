## Problem

On a Wayland server (`--use-ei`, InputCapture portal), a modifier held while crossing to a client is dropped. Hold Alt, cross to a macOS client, keep holding Alt and press `1`: the client gets a bare `1`. Releasing and re-pressing Alt fixes it.

The cause: `EiKeyState` only learns modifiers from EI key events, and a key pressed before capture began never arrives as one. Compositors are not required to send their modifier state when capture activates. Hyprland (0.56) sends `eis_device_keyboard_send_xkb_modifiers` only on a change while captured, and the server ignored that event anyway (`case EI_EVENT_KEYBOARD_MODIFIERS: // FIXME`).

## Fix

- When the primary screen leaves (capture is starting), rebuild the xkb state from the kernel's view of the eight modifier keys (`EVIOCGKEY` on `/dev/input/event*`). The locked modifiers and group are kept. Without read access to `/dev/input` this only clears state left over from the previous capture, which is still more accurate than keeping it.
- Handle `EI_EVENT_KEYBOARD_MODIFIERS` with `xkb_state_update_mask`, so latched and locked modifiers sent by the compositor are applied.

The client side needed no change: a key sent with the Alt mask makes the client press and release Option around it (`KeyMap::mapCommandKey`), so nothing stays stuck on the client.

Reading `/dev/input` is admittedly a workaround for the compositor not reporting the state. If you would rather not depend on it, the `EI_EVENT_KEYBOARD_MODIFIERS` half stands on its own, and I can split it out.

## Testing

Hyprland 0.56.2 server on Arch, macOS client with AeroSpace. Hold Alt, cross, keep holding, press `1` -> the Mac switches to workspace 1 (before: nothing). Released Alt, then typed on the client: plain letters, no stuck Option. The round trip timing is unchanged. The unit and integration tests pass except `CXWindowsScreenTests.fakeMouseMove_nonPrimary_getCursorPosValuesCorrect`, which needs an X display.

## Contributor Checklist:

* [x] This change affects end users and I have created a file in the `doc/newsfragments` directory (and made sure to read the `README.md` in that directory)
* [ ] This change does not affect end users

🤖 Generated with [Claude Code](https://claude.com/claude-code)
