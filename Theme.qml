pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Reads DMS's live Matugen colors from dms-colors.json and re-renders
// whenever the file changes. Falls back to the hardcoded scheme if the file
// is missing (e.g. DMS not running).
QtObject {
    id: root

    readonly property string _xdgCache: Quickshell.env("XDG_CACHE_HOME")
                                        || (Quickshell.env("HOME") + "/.cache")

    // ---- parsed live colors ----
    property var _colors: ({})

    property FileView _colorsFile: FileView {
        path: root._xdgCache + "/DankMaterialShell/dms-colors.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text())
                if (d.colors && d.colors.dark) root._colors = d.colors.dark
            } catch (e) {
                console.warn("makima-mx: failed to parse dms-colors.json:", e)
            }
        }
        onLoadFailed: {
            console.info("makima-mx: dms-colors.json not found; using fallback theme")
        }
    }
    function _c(key, fallback) {
        const v = _colors[key]
        return v ? v : fallback
    }

    // ---- public colors (bindings re-evaluate when _colors changes) ----
    // NOTE: avoid property names like onSurface — QML parses on<Capital> as a signal handler.
    readonly property color background:         _c("background",             "#0a1519")
    readonly property color surfaceLow:         _c("surface_container_low",  "#131d22")
    readonly property color surfaceHigh:        _c("surface_container_high", "#172126")
    readonly property color surfaceVariant:     _c("surface_variant",        "#3e484e")
    readonly property color text:               _c("on_surface",             "#d9e4eb")
    readonly property color textMuted:          _c("on_surface_variant",     "#bdc8cf")
    readonly property color primary:            _c("primary",                "#63d3ff")
    readonly property color primaryFg:          _c("on_primary",             "#003545")
    readonly property color primaryContainer:   _c("primary_container",      "#004d63")
    readonly property color primaryContainerFg: _c("on_primary_container",   "#bce9ff")
    readonly property color outline:            _c("outline",                "#879299")
    readonly property color outlineVariant:     _c("outline_variant",        "#3e484e")
    readonly property color error:              _c("error",                  "#ffb4ab")

    // ---- spacing / radius / fonts (unchanged) ----
    readonly property int spacingXS: 4
    readonly property int spacingS:  8
    readonly property int spacingM:  12
    readonly property int spacingL:  20
    readonly property int spacingXL: 28

    readonly property int radius:  10
    readonly property int radiusS: 6
    readonly property int radiusL: 16

    readonly property int fontSm: 12
    readonly property int fontMd: 14
    readonly property int fontLg: 16
    readonly property int fontXl: 20
}
