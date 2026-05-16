pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "KeyMap.js" as KM

QtObject {
    id: root

    // ---- config ----
    readonly property string _home:       Quickshell.env("HOME")
    readonly property string _xdgConfig:  Quickshell.env("XDG_CONFIG_HOME") || (_home + "/.config")
    readonly property string profilePath: _xdgConfig + "/makima-mx/profiles.json"
    readonly property string makimaDir:   _xdgConfig + "/makima"
    readonly property string globalKey:   "_global"

    // The evdev Name field of the active mouse (= makima's per-device TOML basename).
    // Detected at startup from /proc/bus/input/devices; persisted across runs.
    property string deviceName: "Logitech MX Master 3S"   // fallback until probe runs

    readonly property var buttonCodeOf: ({
        "left":       "BTN_LEFT",
        "right":      "BTN_RIGHT",
        "wheel":      "BTN_MIDDLE",
        "back":       "BTN_SIDE",
        "forward":    "BTN_EXTRA",
        "gesture":    "BTN_FORWARD",
        "mode":       null,
        "thumbwheel": null
    })
    readonly property var idOfButtonCode: ({
        "BTN_LEFT": "left", "BTN_RIGHT": "right", "BTN_MIDDLE": "wheel",
        "BTN_SIDE": "back", "BTN_EXTRA": "forward", "BTN_FORWARD": "gesture"
    })

    // ---- state ----
    // apps[key] = { activeProfile, profiles: { name: { bindings } }, customIconPath?, displayName? }
    // key = "_global" for the device-level TOML, else WM_CLASS for an override.
    property var apps: ({ "_global": { activeProfile: "Default", profiles: { "Default": { bindings: {} } } } })
    property string activeApp: "_global"
    // Explicit display order for app pills. _global always at index 0.
    property var appOrder: ["_global"]

    // ---- derived ----
    readonly property var bindings: {
        const a = apps[activeApp]
        if (!a) return {}
        const p = a.profiles[a.activeProfile]
        return p ? (p.bindings || {}) : {}
    }
    // Public ordered list — drives the UI. Always _global first.
    readonly property var appKeys: {
        // Sync with appOrder: drop missing, append new (sorted), keep _global first.
        const present = Object.keys(apps)
        const known = appOrder.filter(k => apps[k])
        const missing = present.filter(k => known.indexOf(k) < 0 && k !== globalKey).sort()
        let result = known.concat(missing)
        if (result.indexOf(globalKey) < 0) result = [globalKey].concat(result)
        // _global pinned to index 0
        result = [globalKey].concat(result.filter(k => k !== globalKey))
        return result
    }
    readonly property var appOverrideKeys: appKeys.filter(k => k !== globalKey)

    // ---- live status ----
    property bool daemonRunning: false
    property bool deviceConnected: false

    // Currently-focused window's WM_CLASS, reactive via Hyprland IPC
    readonly property string focusedClass: {
        const t = Hyprland.activeToplevel
        if (!t || !t.lastIpcObject) return ""
        return t.lastIpcObject.class || ""
    }
    // The makima config currently in effect for the focused window
    readonly property string effectiveAppKey: {
        const f = focusedClass
        if (f && apps[f]) return f
        return globalKey
    }
    readonly property string effectiveProfileName: {
        const a = apps[effectiveAppKey]
        return a ? a.activeProfile : ""
    }

    property Process _daemonProbe: Process {
        command: ["systemctl", "--user", "is-active", "makima"]
        onExited: (code, status) => root.daemonRunning = (code === 0)
    }
    // Walks /proc/bus/input/devices looking for a Logitech/MX-Master device
    // that has a mouseN handler. Emits the evdev Name (used by makima as TOML basename).
    property Process _deviceProbe: Process {
        command: ["bash", "-c",
            "awk 'BEGIN{n=\"\"} /^I:/{n=\"\"} /^N: Name=/{gsub(/^N: Name=\"|\"$/,\"\",$0); n=$0} /^H: Handlers=/{if(n ~ /Logitech|MX Master/ && $0 ~ /mouse[0-9]/){print n; exit}}' /proc/bus/input/devices"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim()
                if (found) {
                    root.deviceConnected = true
                    if (found !== root.deviceName) {
                        root.deviceName = found
                        root._persistJson()
                        // Pick up any per-app TOMLs for this device that we don't know about
                        root._scanProc.running = true
                    }
                } else {
                    root.deviceConnected = false
                }
            }
        }
    }
    property Timer _statusPoll: Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root._daemonProbe.running = true
            root._deviceProbe.running = true
        }
    }
    readonly property var currentProfileNames: {
        const a = apps[activeApp]
        return a ? Object.keys(a.profiles) : []
    }
    readonly property string currentActiveProfile: {
        const a = apps[activeApp]
        return a ? a.activeProfile : ""
    }

    function tomlPathFor(appKey) {
        if (appKey === globalKey) return makimaDir + "/" + deviceName + ".toml"
        return makimaDir + "/" + deviceName + "::" + appKey + ".toml"
    }
    function customIconFor(appKey) {
        const a = apps[appKey]
        return a && a.customIconPath ? a.customIconPath : ""
    }
    function displayNameFor(appKey) {
        if (appKey === globalKey) return "Global"
        const a = apps[appKey]
        if (a && a.displayName && a.displayName.length > 0) return a.displayName
        return _autoDisplayName(appKey)
    }
    function _autoDisplayName(wmClass) {
        try {
            const e = DesktopEntries.heuristicLookup(wmClass)
            if (e && e.name && e.name.length > 0) return e.name
        } catch (err) { /* ignore */ }
        return wmClass
    }
    function setAppDisplayName(appKey, name) {
        if (!apps[appKey] || appKey === globalKey) return
        const all = Object.assign({}, apps)
        const a = Object.assign({}, all[appKey])
        const trimmed = (name || "").trim()
        const auto = _autoDisplayName(appKey)
        if (trimmed && trimmed !== auto) a.displayName = trimmed
        else delete a.displayName
        all[appKey] = a
        apps = all
        _persistJson()
    }

    // ---- file I/O ----
    property FileView _profileFile: FileView {
        path: root.profilePath
        blockLoading: true
        atomicWrites: true
        onLoaded: root._loadJson(text())
        onLoadFailed: root._loadJson("")
    }
    property FileView _writeTomlFile: FileView {
        path: ""
        atomicWrites: true
    }
    property Process _reloadProc: Process {
        command: ["systemctl", "--user", "restart", "makima"]
    }
    property Process _rmProc: Process { }

    property Process _scanProc: Process {
        running: true
        command: ["bash", "-c",
            "shopt -s nullglob; " +
            "global=\"" + root.makimaDir + "/" + root.deviceName + ".toml\"; " +
            "if [ -f \"$global\" ]; then echo '===MAKIMA-MX-CLASS=== " + root.globalKey + "'; cat \"$global\"; echo '===MAKIMA-MX-END==='; fi; " +
            "for f in \"" + root.makimaDir + "/" + root.deviceName + "::\"*.toml; do " +
            "  base=$(basename \"$f\"); " +
            "  cls=\"${base#" + root.deviceName + "::}\"; cls=\"${cls%.toml}\"; " +
            "  echo \"===MAKIMA-MX-CLASS=== $cls\"; " +
            "  cat \"$f\"; " +
            "  echo \"===MAKIMA-MX-END===\"; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: root._ingestExistingTomls(text)
        }
    }

    // ---- JSON load/save ----
    function _loadJson(jsonText) {
        let data = {}
        try { if (jsonText) data = JSON.parse(jsonText) } catch (e) { data = {} }

        // Restore last-known device name first so file paths work before the probe runs
        if (data.deviceName) deviceName = data.deviceName

        if (data.apps && typeof data.apps === "object" && Object.keys(data.apps).length > 0) {
            // v3+ format
            apps = data.apps
            activeApp = (data.activeApp && data.apps[data.activeApp]) ? data.activeApp : globalKey
            appOrder = Array.isArray(data.appOrder) && data.appOrder.length > 0
                ? data.appOrder
                : [globalKey].concat(Object.keys(data.apps).filter(k => k !== globalKey).sort())
            _ensureGlobal()
            return
        }
        if (data.profiles && typeof data.profiles === "object") {
            // v2 -> v3 migration
            apps = { [globalKey]: { activeProfile: data.activeProfile || "Default", profiles: data.profiles } }
            activeApp = globalKey
            _ensureGlobal()
            _persistJson()
            return
        }
        if (data.bindings) {
            // v1 -> v3 migration
            apps = { [globalKey]: { activeProfile: "Default", profiles: { "Default": { bindings: data.bindings } } } }
            activeApp = globalKey
            _persistJson()
            return
        }
        // empty / new
        apps = { [globalKey]: { activeProfile: "Default", profiles: { "Default": { bindings: {} } } } }
        activeApp = globalKey
        _persistJson()
    }
    function _ensureGlobal() {
        if (!apps[globalKey]) {
            const a = Object.assign({}, apps)
            a[globalKey] = { activeProfile: "Default", profiles: { "Default": { bindings: {} } } }
            apps = a
        }
    }
    function _persistJson() {
        const payload = {
            version: 3,
            deviceName: deviceName,
            activeApp: activeApp,
            apps: apps,
            appOrder: appKeys
        }
        _profileFile.setText(JSON.stringify(payload, null, 2))
    }

    // ---- merging existing per-app TOMLs into state ----
    function _ingestExistingTomls(dumpText) {
        if (!dumpText) return
        const sections = dumpText.split("===MAKIMA-MX-CLASS===")
        const updated = Object.assign({}, apps)
        let touched = false
        for (let i = 1; i < sections.length; i++) {
            const sec = sections[i]
            const nl = sec.indexOf("\n")
            if (nl < 0) continue
            const cls = sec.substring(0, nl).trim()
            const body = sec.substring(nl + 1)
            const endIdx = body.indexOf("===MAKIMA-MX-END===")
            const toml = endIdx >= 0 ? body.substring(0, endIdx) : body
            const parsed = _parseRemapToml(toml)
            // If we don't already have this app in state, seed it with a Default profile from the file.
            // If we do, leave our state alone (our state is the source of truth post-discovery).
            if (!updated[cls]) {
                updated[cls] = {
                    activeProfile: "Default",
                    profiles: { "Default": { bindings: parsed } }
                }
                touched = true
            }
        }
        if (touched) {
            apps = updated
            _persistJson()
        }
    }

    function _parseRemapToml(text) {
        const out = {}
        if (!text) return out
        let inRemap = false
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i]
            const hash = line.indexOf("#")
            if (hash >= 0) line = line.substring(0, hash)
            line = line.trim()
            if (!line) continue
            if (line[0] === "[") {
                inRemap = (line === "[remap]")
                continue
            }
            if (!inRemap) continue
            const m = line.match(/^([A-Z_]+)\s*=\s*\[([^\]]*)\]/)
            if (!m) continue
            const id = idOfButtonCode[m[1]]
            if (!id) continue
            const keys = m[2].split(",").map(s => s.trim().replace(/^"|"$/g, "")).filter(s => s.length > 0)
            out[id] = keys
        }
        return out
    }

    // ---- TOML writing ----
    function _writeTomlFor(appKey) {
        const a = apps[appKey]
        if (!a) return
        const p = a.profiles[a.activeProfile]
        const b = p ? (p.bindings || {}) : {}
        const banner = appKey === globalKey
            ? ["# Generated by makima-mx — device-level TOML.",
               "# Active profile: " + a.activeProfile]
            : ["# Generated by makima-mx — per-app override for " + appKey + ".",
               "# Active profile: " + a.activeProfile]
        _writeTomlFile.path = tomlPathFor(appKey)
        _writeTomlFile.setText(_renderToml(b, banner))
    }
    function _renderToml(bindings, bannerLines) {
        let lines = bannerLines.slice()
        lines.push("")
        lines.push("[remap]")
        const ids = Object.keys(bindings)
        for (let i = 0; i < ids.length; i++) {
            const id = ids[i]
            const code = buttonCodeOf[id]
            if (!code) continue
            const keys = bindings[id]
            if (!keys || keys.length === 0) continue
            const arr = keys.map(k => '"' + k + '"').join(", ")
            lines.push(code + " = [" + arr + "]")
        }
        lines.push("")
        return lines.join("\n")
    }
    function _deleteAppTomlFile(appKey) {
        if (appKey === globalKey) return
        _rmProc.command = ["rm", "-f", tomlPathFor(appKey)]
        _rmProc.running = true
    }

    // ---- public API ----
    function isRemappable(buttonId) { return buttonCodeOf[buttonId] != null }
    function bindingFor(buttonId) {
        const b = bindings[buttonId]
        return (b && b.length > 0) ? b : []
    }
    function labelFor(buttonId) {
        const keys = bindingFor(buttonId)
        if (keys.length === 0) return "default"
        return KM.comboLabel(keys)
    }

    // app navigation
    function setActiveApp(appKey) {
        if (!apps[appKey] || appKey === activeApp) return
        activeApp = appKey
        _persistJson()
    }
    function createApp(wmClass) {
        const cls = (wmClass || "").trim()
        if (!cls || cls === globalKey || apps[cls] != null) return false
        const all = Object.assign({}, apps)
        all[cls] = { activeProfile: "Default", profiles: { "Default": { bindings: {} } } }
        apps = all
        // Append to order (after the last existing)
        appOrder = appOrder.concat([cls])
        activeApp = cls
        _persistJson()
        _writeTomlFor(cls)
        _reloadProc.running = true
        return true
    }
    function moveApp(fromIdx, toIdx) {
        const ks = appKeys.slice()
        if (fromIdx < 0 || fromIdx >= ks.length) return
        if (toIdx < 0 || toIdx >= ks.length) return
        // _global pinned at 0
        if (fromIdx === 0 || toIdx === 0) return
        if (fromIdx === toIdx) return
        const item = ks.splice(fromIdx, 1)[0]
        ks.splice(toIdx, 0, item)
        appOrder = ks
        _persistJson()
    }
    function deleteApp(appKey) {
        if (appKey === globalKey || !apps[appKey]) return false
        const all = Object.assign({}, apps)
        delete all[appKey]
        apps = all
        appOrder = appOrder.filter(k => k !== appKey)
        if (activeApp === appKey) activeApp = globalKey
        _deleteAppTomlFile(appKey)
        _persistJson()
        _reloadProc.running = true
        return true
    }
    function setAppIcon(appKey, path) {
        if (!apps[appKey]) return
        const all = Object.assign({}, apps)
        const a = Object.assign({}, all[appKey])
        if (path && path.length > 0) a.customIconPath = path
        else delete a.customIconPath
        all[appKey] = a
        apps = all
        _persistJson()
    }

    // profile management (within active app)
    function setActiveProfile(name) {
        const a = apps[activeApp]
        if (!a || !a.profiles[name] || a.activeProfile === name) return
        const all = Object.assign({}, apps)
        const cur = Object.assign({}, all[activeApp])
        cur.activeProfile = name
        all[activeApp] = cur
        apps = all
        _persistJson()
        _writeTomlFor(activeApp)
        _reloadProc.running = true
    }
    function createProfile(name) {
        const t = (name || "").trim()
        if (!t) return false
        const a = apps[activeApp]
        if (!a || a.profiles[t]) return false
        const all = Object.assign({}, apps)
        const cur = Object.assign({}, all[activeApp])
        const ps = Object.assign({}, cur.profiles)
        ps[t] = { bindings: {} }
        cur.profiles = ps
        cur.activeProfile = t
        all[activeApp] = cur
        apps = all
        _persistJson()
        _writeTomlFor(activeApp)
        _reloadProc.running = true
        return true
    }
    function deleteProfile(name) {
        const a = apps[activeApp]
        if (!a || !a.profiles[name]) return false
        if (Object.keys(a.profiles).length <= 1) return false
        const all = Object.assign({}, apps)
        const cur = Object.assign({}, all[activeApp])
        const ps = Object.assign({}, cur.profiles)
        delete ps[name]
        cur.profiles = ps
        if (cur.activeProfile === name) cur.activeProfile = Object.keys(ps)[0]
        all[activeApp] = cur
        apps = all
        _persistJson()
        _writeTomlFor(activeApp)
        _reloadProc.running = true
        return true
    }

    // bindings (operate on current app + profile)
    function setBinding(buttonId, keyNames) {
        const a = apps[activeApp]
        if (!a) return
        const all = Object.assign({}, apps)
        const cur = Object.assign({}, all[activeApp])
        const ps = Object.assign({}, cur.profiles)
        const profile = Object.assign({}, ps[cur.activeProfile] || { bindings: {} })
        const b = Object.assign({}, profile.bindings || {})
        if (!keyNames || keyNames.length === 0) delete b[buttonId]
        else b[buttonId] = keyNames.slice()
        profile.bindings = b
        ps[cur.activeProfile] = profile
        cur.profiles = ps
        all[activeApp] = cur
        apps = all
        _persistJson()
        _writeTomlFor(activeApp)
        _reloadProc.running = true
    }
    function clearBinding(buttonId) { setBinding(buttonId, []) }
}
