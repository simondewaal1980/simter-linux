.pragma library

// ReportParser.js — parser voor de `bspc subscribe report`-regel.
//
// Formaat (zie bspwm(1), REPORT FORMAT):
//
//   W[M|m]<monitor> : O/o/F/f/U/u<desktop> ... : L(T|M) [: T(...) : G(...)] ...
//
// Let op:
// - De regel begint met de configureerbare status_prefix (standaard "W"),
//   direct gevolgd door de eerste monitor (M of m).
// - L, T en G horen bij de monitor die ervoor genoemd is. Alleen de monitor
//   met een hoofdletter (M) is gefocust; alleen daarvan nemen we layout en
//   node-status over in het eindresultaat.
// - Heeft de gefocuste desktop geen gefocuste node (lege desktop of alleen
//   receptacles zonder client), dan ontbreken T en G volledig.
// - T@ betekent: de gefocuste node is een receptacle zonder client.

function emptyFlags() {
    return {
        sticky: false,
        private: false,
        locked: false,
        marked: false
    }
}

function emptyMonitor(name, focused) {
    return {
        name: name,
        focused: focused,
        layout: "tiled",
        activeNodeState: "",
        activeNodeFlags: emptyFlags(),
        desktops: []
    }
}

function initialState() {
    return {
        monitors: [],
        desktops: [],
        focusedMonitor: "",
        focusedDesktop: "",
        layout: "tiled",
        activeNodeState: "",
        activeNodeFlags: emptyFlags()
    }
}

function stateName(character) {
    switch (character) {
    case "T": return "tiled"
    case "P": return "pseudo_tiled"
    case "F": return "floating"
    case "=": return "fullscreen"
    case "@": return "receptacle"
    default: return ""
    }
}

function flagsFromString(flags) {
    return {
        sticky: flags.indexOf("S") >= 0,
        private: flags.indexOf("P") >= 0,
        locked: flags.indexOf("L") >= 0,
        marked: flags.indexOf("M") >= 0
    }
}

function parseReport(report) {
    var result = initialState()
    if (!report)
        return result

    var text = String(report).trim()
    if (text.length === 0)
        return result

    var items = text.split(":")
    var currentMonitor = null

    for (var i = 0; i < items.length; i++) {
        var item = items[i]
        if (item.length === 0)
            continue

        var type = item.charAt(0)

        // De allereerste regel begint met status_prefix ("W").
        if (i === 0 && type === "W") {
            item = item.substring(1)
            if (item.length === 0)
                continue
            type = item.charAt(0)
        }

        switch (type) {
        case "M":
        case "m": {
            currentMonitor = emptyMonitor(item.substring(1), type === "M")
            result.monitors.push(currentMonitor)
            if (currentMonitor.focused)
                result.focusedMonitor = currentMonitor.name
            break
        }

        case "O":
        case "o":
        case "F":
        case "f":
        case "U":
        case "u": {
            if (currentMonitor === null) {
                currentMonitor = emptyMonitor("", true)
                result.monitors.push(currentMonitor)
            }

            var focused = (type === "O" || type === "F" || type === "U")
            var desktop = {
                name: item.substring(1),
                monitor: currentMonitor.name,
                focused: focused,
                occupied: (type === "O" || type === "o" || type === "U" || type === "u"),
                urgent: (type === "U" || type === "u")
            }
            currentMonitor.desktops.push(desktop)
            result.desktops.push(desktop)

            if (focused && currentMonitor.focused)
                result.focusedDesktop = desktop.name
            break
        }

        case "L": {
            var layout = item.substring(1) === "M" ? "monocle" : "tiled"
            if (currentMonitor === null) {
                currentMonitor = emptyMonitor("", true)
                result.monitors.push(currentMonitor)
            }
            currentMonitor.layout = layout
            if (currentMonitor.focused)
                result.layout = layout
            break
        }

        case "T": {
            var state = stateName(item.substring(1))
            if (currentMonitor !== null)
                currentMonitor.activeNodeState = state
            if (currentMonitor === null || currentMonitor.focused)
                result.activeNodeState = state
            break
        }

        case "G": {
            var flags = flagsFromString(item.substring(1))
            if (currentMonitor !== null)
                currentMonitor.activeNodeFlags = flags
            if (currentMonitor === null || currentMonitor.focused)
                result.activeNodeFlags = flags
            break
        }
        }
    }

    return result
}
