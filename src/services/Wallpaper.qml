pragma Singleton

// Wallpaper.qml — wallpaperbeheer voor de bar en het wallpapervenster.
//
// De lijst komt uit dezelfde map als scripts/wallpaper-theme.sh gebruikt:
// ~/Pictures/wallpaper.jpg plus ~/Pictures/Wallpapers/. Toepassen gebeurt via
// dat script, zodat wallpaper, matugen-palet, BSPWM-randen en de bar altijd
// synchroon blijven. Toevoegen kopieert een gekozen afbeelding naar de
// wallpapermappen; verwijderen kan alleen uit die map.
//
// De huidige wallpaper staat in ~/.config/bspwm/wallpaper (geschreven door
// wallpaper-theme.sh). FileView.watchChanges houdt het venster actueel wanneer
// het script buiten de UI om wordt gestart (bijvoorbeeld met Super+W).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: wall

    readonly property string home: Quickshell.env("HOME")
    readonly property string defaultWallpaper: home + "/Pictures/wallpaper.jpg"
    readonly property string wallpaperDir: home + "/Pictures/Wallpapers"
    readonly property string configHome: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME")
        return xdg && xdg.length > 0 ? xdg : home + "/.config"
    }
    readonly property string statePath: configHome + "/bspwm/wallpaper"
    readonly property string themeScript: home + "/projecten/quickshell/scripts/wallpaper-theme.sh"

    // items: [{ path, name, isDefault }], gesorteerd op naam (standaard eerst).
    property var items: []
    property string currentPath: ""
    property bool scanning: false
    property bool busy: false
    property string lastError: ""
    property string lastAction: ""

    property string applyingPath: ""
    property string pendingAdd: ""
    property string pendingRemove: ""
    property string applyOutput: ""
    property string applyError: ""

    signal added(string path)
    signal removed(string path)

    function fileName(path) {
        if (!path)
            return ""
        const parts = String(path).split("/")
        return parts[parts.length - 1]
    }

    // Qt leest lokale paden met spaties en niet-ASCII tekens betrouwbaar als
    // elk paddeel procent-gecodeerd is.
    function fileUrl(path) {
        if (!path)
            return ""
        const parts = String(path).split("/")
        for (let i = 0; i < parts.length; i++)
            parts[i] = encodeURIComponent(parts[i])
        return "file://" + parts.join("/")
    }

    function imageExtension(path) {
        const name = fileName(path)
        const dot = name.lastIndexOf(".")
        return dot >= 0 ? name.slice(dot).toLowerCase() : ""
    }

    // Leesbare naam voor de kaarten: griekenland-01-santorini-oia.jpg wordt
    // “Santorini Oia”, wallpaper.jpg “Standaard” en wallpaper-02 “Wallpaper 02”.
    function displayName(path) {
        let name = fileName(path)
        let stem = name.replace(/\.[^.]+$/, "")
        if (stem === "wallpaper")
            return "Standaard"

        const greek = stem.match(/^griekenland-\d+-(.+)$/)
        if (greek)
            stem = greek[1]
        else {
            const numbered = stem.match(/^wallpaper-(\d+)$/)
            if (numbered)
                return "Wallpaper " + numbered[1]
        }

        const dutch = {
            "athene": "Athene",
            "crete": "Kreta",
            "rhodes": "Rhodos"
        }
        const words = stem.split(/[-_]+/)
        for (let i = 0; i < words.length; i++) {
            const lower = words[i].toLowerCase()
            words[i] = dutch[lower]
                || (lower.charAt(0).toUpperCase() + lower.slice(1))
        }
        return words.join(" ")
    }

    function isImage(path) {
        const ext = imageExtension(path)
        return ext === ".jpg" || ext === ".jpeg" || ext === ".png"
            || ext === ".webp"
    }

    function hasPath(path) {
        for (let i = 0; i < items.length; i++) {
            if (items[i].path === path)
                return true
        }
        return false
    }

    function syncCurrent() {
        const text = stateFile.text()
        const value = text === null || text === undefined ? "" : String(text).trim()
        currentPath = value.length > 0 ? value : ""
    }

    function refresh() {
        if (listProcess.running)
            return
        scanning = true
        listProcess.running = true
    }

    // Start wallpaper-theme.sh voor een bestaand bestand.
    function apply(path) {
        if (busy || !path)
            return false
        busy = true
        lastError = ""
        lastAction = ""
        applyOutput = ""
        applyError = ""
        applyingPath = path
        applyProcess.command = [themeScript, path]
        applyProcess.running = true
        return true
    }

    // Laat wallpaper-theme.sh zelf de volgende uit de lijst kiezen.
    function next() {
        if (busy)
            return false
        busy = true
        lastError = ""
        lastAction = ""
        applyOutput = ""
        applyError = ""
        applyingPath = ""
        applyProcess.command = [themeScript, "next"]
        applyProcess.running = true
        return true
    }

    // Kopieert een afbeelding naar ~/Pictures/Wallpapers en geeft het doelpad
    // terug. Bestaat de naam al, dan komt er -2, -3, … achter.
    function add(source) {
        if (!source)
            return ""
        if (!isImage(source)) {
            lastError = "Alleen JPG, PNG en WebP worden ondersteund"
            return ""
        }
        if (busy) {
            lastError = "Even wachten: er loopt al een wallpaperactie"
            return ""
        }
        if (source.indexOf(wallpaperDir + "/") === 0) {
            lastError = ""
            lastAction = "Deze wallpaper staat al in " + wallpaperDir
            return source
        }

        const name = fileName(source)
        const dot = name.lastIndexOf(".")
        const stem = dot > 0 ? name.slice(0, dot) : name
        const ext = dot > 0 ? name.slice(dot) : ".jpg"

        let destination = wallpaperDir + "/" + name
        let counter = 2
        while (hasPath(destination)) {
            destination = wallpaperDir + "/" + stem + "-" + counter + ext
            counter++
        }

        busy = true
        lastError = ""
        lastAction = ""
        applyOutput = ""
        applyError = ""
        pendingAdd = destination
        // -p maakt de map aan; de bron wordt niet verplaatst maar gekopieerd.
        addProcess.command = ["sh", "-c",
            'mkdir -p -- "$1" && cp -- "$2" "$3"',
            "wallpaper-add", wallpaperDir, source, destination]
        addProcess.running = true
        return destination
    }

    function remove(path) {
        if (busy || !path)
            return false
        if (path.indexOf(wallpaperDir + "/") !== 0) {
            lastError = "Alleen wallpapers uit " + wallpaperDir + " kunnen worden verwijderd"
            return false
        }
        if (path === currentPath) {
            lastError = "De actieve wallpaper kan niet worden verwijderd"
            return false
        }

        busy = true
        lastError = ""
        lastAction = ""
        applyOutput = ""
        applyError = ""
        pendingRemove = path
        removeProcess.command = ["rm", "--", path]
        removeProcess.running = true
        return true
    }

    function status() {
        return {
            wallpaperDir: wallpaperDir,
            defaultWallpaper: defaultWallpaper,
            statePath: statePath,
            current: currentPath,
            count: items.length,
            scanning: scanning,
            busy: busy,
            lastAction: lastAction,
            lastError: lastError,
            items: items
        }
    }

    FileView {
        id: stateFile
        path: wall.statePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: wall.syncCurrent()
        onFileChanged: reload()
    }

    Process {
        id: listProcess

        // Zelfde bron als wallpaper-theme.sh: de standaardwallpaper plus alle
        // afbeeldingen in de wallpapermappen. De sortering gebeurt in QML.
        command: ["sh", "-c",
            '[ -r "$1" ] && printf "%s\\n" "$1"; ' +
            '[ -d "$2" ] && find "$2" -maxdepth 1 -type f ' +
            '\\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" ' +
            '-o -iname "*.webp" \\) -print; exit 0',
            "wallpaper-list", wall.defaultWallpaper, wall.wallpaperDir]

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                const lines = text.split("\n")
                const seen = ({})
                const result = []

                for (let i = 0; i < lines.length; i++) {
                    const path = lines[i].trim()
                    if (path.length === 0 || seen[path])
                        continue
                    seen[path] = true
                    result.push({
                        path: path,
                        name: wall.fileName(path),
                        isDefault: path === wall.defaultWallpaper
                    })
                }

                result.sort(function(a, b) {
                    if (a.isDefault !== b.isDefault)
                        return a.isDefault ? -1 : 1
                    return a.name.localeCompare(b.name)
                })

                wall.items = result
            }
        }

        onExited: wall.scanning = false
    }

    Process {
        id: applyProcess

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: wall.applyOutput = text
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: wall.applyError = text
        }

        onExited: (exitCode) => {
            wall.busy = false
            if (exitCode === 0) {
                if (wall.applyingPath.length > 0) {
                    wall.currentPath = wall.applyingPath
                    wall.lastAction = "Wallpaper toegepast: "
                        + wall.fileName(wall.applyingPath)
                } else {
                    wall.syncCurrent()
                    wall.lastAction = "Volgende wallpaper toegepast"
                }
                wall.refresh()
            } else {
                const detail = wall.applyError.trim().length > 0
                    ? wall.applyError.trim()
                    : wall.applyOutput.trim()
                wall.lastError = detail.length > 0
                    ? detail
                    : "Wallpaper toepassen mislukt (exit " + exitCode + ")"
            }
            wall.applyingPath = ""
        }
    }

    Process {
        id: addProcess

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: wall.applyError = text
        }

        onExited: (exitCode) => {
            wall.busy = false
            const destination = wall.pendingAdd
            wall.pendingAdd = ""

            if (exitCode === 0) {
                wall.lastAction = "Toegevoegd: " + wall.fileName(destination)
                wall.refresh()
                wall.added(destination)
            } else {
                const detail = wall.applyError.trim()
                wall.lastError = detail.length > 0
                    ? detail
                    : "Wallpaper toevoegen mislukt (exit " + exitCode + ")"
            }
        }
    }

    Process {
        id: removeProcess

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: wall.applyError = text
        }

        onExited: (exitCode) => {
            wall.busy = false
            const path = wall.pendingRemove
            wall.pendingRemove = ""

            if (exitCode === 0) {
                wall.lastAction = "Verwijderd: " + wall.fileName(path)
                wall.refresh()
                wall.removed(path)
            } else {
                const detail = wall.applyError.trim()
                wall.lastError = detail.length > 0
                    ? detail
                    : "Wallpaper verwijderen mislukt (exit " + exitCode + ")"
            }
        }
    }

    Component.onCompleted: {
        wall.syncCurrent()
        wall.refresh()
    }
}
