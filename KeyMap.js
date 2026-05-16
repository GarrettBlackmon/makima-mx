.pragma library

// Qt.Key_* (the integer values) -> makima/evdev "KEY_*" name.
// Built manually for common keys. Add more as needed.
//
// Note: Qt doesn't distinguish left/right modifiers in event.key — we
// always emit KEY_LEFT* for those. Right variants would need to read
// event.nativeScanCode instead.

var _MAP = {
    // Letters (Qt.Key_A == 0x41)
    0x41: "KEY_A", 0x42: "KEY_B", 0x43: "KEY_C", 0x44: "KEY_D",
    0x45: "KEY_E", 0x46: "KEY_F", 0x47: "KEY_G", 0x48: "KEY_H",
    0x49: "KEY_I", 0x4a: "KEY_J", 0x4b: "KEY_K", 0x4c: "KEY_L",
    0x4d: "KEY_M", 0x4e: "KEY_N", 0x4f: "KEY_O", 0x50: "KEY_P",
    0x51: "KEY_Q", 0x52: "KEY_R", 0x53: "KEY_S", 0x54: "KEY_T",
    0x55: "KEY_U", 0x56: "KEY_V", 0x57: "KEY_W", 0x58: "KEY_X",
    0x59: "KEY_Y", 0x5a: "KEY_Z",

    // Digits
    0x30: "KEY_0", 0x31: "KEY_1", 0x32: "KEY_2", 0x33: "KEY_3",
    0x34: "KEY_4", 0x35: "KEY_5", 0x36: "KEY_6", 0x37: "KEY_7",
    0x38: "KEY_8", 0x39: "KEY_9",

    // Function keys
    0x01000030: "KEY_F1",  0x01000031: "KEY_F2",  0x01000032: "KEY_F3",
    0x01000033: "KEY_F4",  0x01000034: "KEY_F5",  0x01000035: "KEY_F6",
    0x01000036: "KEY_F7",  0x01000037: "KEY_F8",  0x01000038: "KEY_F9",
    0x01000039: "KEY_F10", 0x0100003a: "KEY_F11", 0x0100003b: "KEY_F12",

    // Modifiers
    0x01000020: "KEY_LEFTSHIFT",  // Shift
    0x01000021: "KEY_LEFTCTRL",   // Control
    0x01000023: "KEY_LEFTALT",    // Alt
    0x01000022: "KEY_LEFTMETA",   // Meta (Super)
    0x01001103: "KEY_RIGHTALT",   // AltGr

    // Whitespace / navigation
    0x01000004: "KEY_ENTER",
    0x01000001: "KEY_TAB",
    0x01000000: "KEY_ESC",
    0x01000003: "KEY_BACKSPACE",
    0x01000005: "KEY_INSERT",
    0x01000007: "KEY_DELETE",
    0x01000006: "KEY_PAUSE",
    0x01000009: "KEY_SYSRQ",      // Print
    0x01000010: "KEY_HOME",
    0x01000011: "KEY_END",
    0x01000012: "KEY_LEFT",
    0x01000013: "KEY_UP",
    0x01000014: "KEY_RIGHT",
    0x01000015: "KEY_DOWN",
    0x01000016: "KEY_PAGEUP",
    0x01000017: "KEY_PAGEDOWN",
    0x01000024: "KEY_CAPSLOCK",
    0x01000025: "KEY_NUMLOCK",
    0x01000026: "KEY_SCROLLLOCK",
    0x20:       "KEY_SPACE",

    // Punctuation (US layout)
    0x21: "KEY_1",            // ! (Shift+1)
    0x22: "KEY_APOSTROPHE",   // "
    0x23: "KEY_3",            // #
    0x24: "KEY_4",            // $
    0x25: "KEY_5",            // %
    0x26: "KEY_7",            // &
    0x27: "KEY_APOSTROPHE",   // '
    0x28: "KEY_9",            // (
    0x29: "KEY_0",            // )
    0x2a: "KEY_8",            // *
    0x2b: "KEY_EQUAL",        // +
    0x2c: "KEY_COMMA",        // ,
    0x2d: "KEY_MINUS",        // -
    0x2e: "KEY_DOT",          // .
    0x2f: "KEY_SLASH",        // /
    0x3a: "KEY_SEMICOLON",    // :
    0x3b: "KEY_SEMICOLON",    // ;
    0x3c: "KEY_COMMA",        // <
    0x3d: "KEY_EQUAL",        // =
    0x3e: "KEY_DOT",          // >
    0x3f: "KEY_SLASH",        // ?
    0x40: "KEY_2",            // @
    0x5b: "KEY_LEFTBRACE",    // [
    0x5c: "KEY_BACKSLASH",    // \
    0x5d: "KEY_RIGHTBRACE",   // ]
    0x5e: "KEY_6",            // ^
    0x5f: "KEY_MINUS",        // _
    0x60: "KEY_GRAVE",        // `
    0x7b: "KEY_LEFTBRACE",    // {
    0x7c: "KEY_BACKSLASH",    // |
    0x7d: "KEY_RIGHTBRACE",   // }
    0x7e: "KEY_GRAVE"         // ~
}

function fromQtKey(qtKey) {
    return _MAP[qtKey] || null
}

// Human-friendly label for the chip in the modal / list ("Shift+/")
var _LABEL = {
    "KEY_LEFTSHIFT": "Shift", "KEY_RIGHTSHIFT": "Shift",
    "KEY_LEFTCTRL":  "Ctrl",  "KEY_RIGHTCTRL":  "Ctrl",
    "KEY_LEFTALT":   "Alt",   "KEY_RIGHTALT":   "Alt",
    "KEY_LEFTMETA":  "Super", "KEY_RIGHTMETA":  "Super",
    "KEY_ENTER": "Enter", "KEY_TAB": "Tab", "KEY_ESC": "Esc",
    "KEY_BACKSPACE": "Bksp", "KEY_SPACE": "Space",
    "KEY_LEFT": "←", "KEY_RIGHT": "→", "KEY_UP": "↑", "KEY_DOWN": "↓",
    "KEY_SLASH": "/", "KEY_BACKSLASH": "\\",
    "KEY_COMMA": ",", "KEY_DOT": ".",
    "KEY_SEMICOLON": ";", "KEY_APOSTROPHE": "'",
    "KEY_LEFTBRACE": "[", "KEY_RIGHTBRACE": "]",
    "KEY_MINUS": "-", "KEY_EQUAL": "=", "KEY_GRAVE": "`"
}

function label(keyName) {
    if (_LABEL[keyName]) return _LABEL[keyName]
    if (keyName && keyName.indexOf("KEY_") === 0) return keyName.substring(4)
    return keyName || "?"
}

function comboLabel(keys) {
    if (!keys || keys.length === 0) return "(unbound)"
    return keys.map(label).join("+")
}
