pragma Singleton

// Updates.qml — beschikbare systeem- en Flatpak-updates.
//
// De service controleert periodiek `apt list --upgradable` en
// `flatpak remote-ls --updates`. Beide commando's zijn alleen-lezen en werken
// zonder root. `apt list` leest de lokale pakketindex; die index wordt pas
// bijgewerkt door `apt-get update`. Daarom draait een expliciete verversing
// (`refresh(true)`, via de verversknop of `qs ipc call updates refresh`)
// eerst `apt-get update` met elevatie. De periodieke controle en het openen
// van de popup gebruiken de bestaande index, zodat daar geen
// wachtwoordprompt voor nodig is.
//
// Flatpak is optioneel: ontbreekt het programma, dan blijft de service gewoon
// APT-updates tonen. Voor APT is elevatie nodig; standaard wordt pkexec
// gebruikt (net als bij Snapper). Met UPDATES_ELEVATE is dat te vervangen,
// bijvoorbeeld "sudo -n" of leeg voor geen elevatie. UPDATES_APT_BIN,
// UPDATES_APT_GET_BIN en UPDATES_FLATPAK_BIN zijn bedoeld voor tests of
// afwijkende installaties.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string aptBin: {
        const override = Quickshell.env("UPDATES_APT_BIN")
        if (override && override.length > 0)
            return override
        return "apt"
    }

    readonly property string aptGetBin: {
        const override = Quickshell.env("UPDATES_APT_GET_BIN")
        if (override && override.length > 0)
            return override
        return "apt-get"
    }

    readonly property string flatpakBin: {
        const override = Quickshell.env("UPDATES_FLATPAK_BIN")
        if (override && override.length > 0)
            return override
        return "flatpak"
    }

    // Leeg = geen elevatie; standaard vraagt pkexec om bevoegdheid.
    readonly property string elevateCommand: {
        const override = Quickshell.env("UPDATES_ELEVATE")
        if (override === undefined || override === null)
            return "pkexec"
        return String(override).trim()
    }

    readonly property int refreshInterval: 30 * 60 * 1000

    // --- Status -----------------------------------------------------------

    property bool checked: false
    property bool loading: false
    property bool busy: false
    property bool aptAvailable: true
    property bool flatpakAvailable: true
    property string lastError: ""
    property string lastAction: ""
    property var lastUpdated: null

    property var aptUpdates: []
    property var flatpakUpdates: []

    readonly property int aptCount: root.aptUpdates.length
    readonly property int flatpakCount: root.flatpakUpdates.length
    readonly property int totalCount: root.aptCount + root.flatpakCount
    readonly property bool hasUpdates: root.totalCount > 0
    readonly property bool anyManagerAvailable: root.aptAvailable
        || root.flatpakAvailable
    readonly property bool hasProblem: root.checked && !root.anyManagerAvailable

    // --- Interne processtatus --------------------------------------------

    property int pendingListings: 0
    property string listingError: ""
    property string aptOutput: ""
    property string aptError: ""
    property string flatpakOutput: ""
    property string flatpakError: ""

    // Alleen bij een expliciete verversing wordt `apt-get update` gedraaid.
    property bool wantIndexRefresh: false
    property bool fetchingIndex: false
    property string indexOutput: ""
    property string indexError: ""

    property var updateQueue: []
    property string pendingUpdate: ""
    property string updateOutput: ""
    property string updateError: ""

    signal updated()
    signal updateFinished(bool ok, string message)

    // --- Hulpfuncties -----------------------------------------------------

    function firstLine(value) {
        const text = String(value === null || value === undefined ? "" : value).trim()
        if (text.length === 0)
            return ""
        return text.split("\n")[0]
    }

    function cleanError(stderrText, stdoutText) {
        let detail = root.firstLine(stderrText)
        if (detail.length === 0)
            detail = root.firstLine(stdoutText)
        return detail
    }

    function noteError(message) {
        if (message.length === 0 || root.listingError.length > 0)
            return
        root.listingError = message
    }

    function updatedLabel() {
        if (root.lastUpdated === null)
            return "nooit"

        const now = new Date()
        const updated = root.lastUpdated
        const sameDay = updated.getFullYear() === now.getFullYear()
            && updated.getMonth() === now.getMonth()
            && updated.getDate() === now.getDate()
        const pattern = sameDay ? "HH:mm" : "d MMM HH:mm"
        return updated.toLocaleString(Qt.locale("nl_NL"), pattern)
    }

    // --- Uitvoer parsen ---------------------------------------------------

    function parseApt(text) {
        const result = []
        const lines = String(text === null || text === undefined ? "" : text)
            .split("\n")

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            // Regels zien eruit als:
            //   pakket/suite 1.2.3 amd64 [upgradable from: 1.2.2]
            // De locatie kan met LC_ALL=C ook Nederlands zijn; beide varianten
            // worden ondersteund.
            if (line.length === 0 || line.indexOf("/") < 0
                    || line.indexOf("[") < 0)
                continue

            const parts = line.split(/\s+/)
            if (parts.length < 3)
                continue

            const namePart = parts[0]
            const name = namePart.split("/")[0]
            if (name.length === 0)
                continue

            const match = line.match(
                /\[(?:upgradable from|opwaardeerbaar van):\s*([^\]]+)\]/)
            const oldVersion = match ? match[1].trim() : ""

            result.push({
                id: "apt:" + name,
                source: "apt",
                name: name,
                version: parts[1],
                oldVersion: oldVersion,
                branch: "",
                origin: namePart.split("/")[1] || ""
            })
        }

        result.sort(function(a, b) {
            return a.name.localeCompare(b.name)
        })
        return result
    }

    function parseFlatpak(text) {
        const result = []
        const lines = String(text === null || text === undefined ? "" : text)
            .split("\n")

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line.length === 0)
                continue

            // --columns=application,branch,origin,version gebruikt tabs.
            let columns = line.split("\t")
            if (columns.length < 4)
                columns = line.split(/\s+/)

            const app = String(columns[0] || "").trim()
            if (app.length === 0)
                continue

            const branch = String(columns[1] || "").trim()
            const origin = String(columns[2] || "").trim()
            const version = columns.length > 3
                ? String(columns[3] || "").trim() : ""

            result.push({
                id: "flatpak:" + app + ":" + branch,
                source: "flatpak",
                name: app,
                version: version,
                oldVersion: "",
                branch: branch,
                origin: origin
            })
        }

        result.sort(function(a, b) {
            return a.name.localeCompare(b.name)
        })
        return result
    }

    // --- Controleren ------------------------------------------------------

    // `fetchIndex` is alleen true bij een bewuste verversing: dan wordt eerst
    // `apt-get update` gedraaid, zodat de lijst nieuwe pakketten laat zien.
    // Zonder die stap leest `apt list --upgradable` de oude systeemindex en
    // blijft het aantal updates dus achter.
    function refresh(fetchIndex) {
        if (root.loading || root.busy)
            return

        root.wantIndexRefresh = fetchIndex === true
        root.loading = true
        root.listingError = ""
        root.lastError = ""
        availabilityProcess.running = true
    }

    function handleAvailability(text) {
        root.aptAvailable = false
        root.flatpakAvailable = false

        const lines = String(text === null || text === undefined ? "" : text)
            .split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line === root.aptBin + "=1")
                root.aptAvailable = true
            else if (line === root.flatpakBin + "=1")
                root.flatpakAvailable = true
        }
    }

    function startListings() {
        if (root.wantIndexRefresh && root.aptAvailable) {
            root.wantIndexRefresh = false
            root.fetchingIndex = true
            root.indexOutput = ""
            root.indexError = ""
            indexProcess.running = true
            indexGuardTimer.restart()
            return
        }

        root.wantIndexRefresh = false
        root.startPackageListings()
    }

    function startPackageListings() {
        root.pendingListings = 0

        if (root.aptAvailable) {
            root.aptOutput = ""
            root.aptError = ""
            root.pendingListings++
            aptProcess.running = true
        } else {
            root.aptUpdates = []
        }

        if (root.flatpakAvailable) {
            root.flatpakOutput = ""
            root.flatpakError = ""
            root.pendingListings++
            flatpakProcess.running = true
        } else {
            root.flatpakUpdates = []
        }

        if (root.pendingListings === 0) {
            root.loading = false
            root.checked = true
            root.lastError = "Geen pakketbeheer gevonden (apt of flatpak)"
            root.updated()
        }
    }

    function finishListing() {
        root.pendingListings--
        if (root.pendingListings > 0)
            return

        root.fetchingIndex = false
        root.loading = false
        root.checked = true
        root.lastUpdated = new Date()
        root.lastError = root.listingError
        root.updated()
    }

    // --- Bijwerken --------------------------------------------------------

    function elevationPrefix() {
        if (root.elevateCommand.length === 0)
            return []
        return root.elevateCommand.split(/\s+/)
    }

    function aptUpdateCommand() {
        // full-upgrade (voorheen dist-upgrade) is nodig voor updates die
        // nieuwe dependencies installeren of verouderde pakketten vervangen;
        // met een gewone `upgrade` blijven die als "kept back" staan.
        return root.elevationPrefix().concat([
            "sh", "-c", root.aptGetBin + " update && "
                + root.aptGetBin + " -y full-upgrade"
        ])
    }

    function aptIndexRefreshCommand() {
        // Alleen de pakketindex bijwerken; dit is de stap die `apt list
        // --upgradable` nieuwe updates laat zien.
        return root.elevationPrefix().concat([root.aptGetBin, "update"])
    }

    function flatpakUpdateCommand() {
        return [root.flatpakBin, "update", "--noninteractive", "-y"]
    }

    function updateAll() {
        if (root.busy || root.loading || !root.hasUpdates
                || !root.anyManagerAvailable)
            return false

        const queue = []
        if (root.aptAvailable && root.aptCount > 0)
            queue.push("apt")
        if (root.flatpakAvailable && root.flatpakCount > 0)
            queue.push("flatpak")
        if (queue.length === 0)
            return false

        root.updateQueue = queue
        root.busy = true
        root.lastError = ""
        root.lastAction = ""
        root.updateOutput = ""
        root.updateError = ""
        root.runNextUpdate()
        return true
    }

    function runNextUpdate() {
        if (root.updateQueue.length === 0) {
            root.finishUpdate(true)
            return
        }

        const step = root.updateQueue.shift()
        root.pendingUpdate = step
        root.updateOutput = ""
        root.updateError = ""
        updateProcess.command = step === "apt"
            ? root.aptUpdateCommand() : root.flatpakUpdateCommand()
        updateProcess.running = true
        updateGuardTimer.restart()
    }

    function finishUpdate(ok) {
        updateGuardTimer.stop()
        root.busy = false
        root.pendingUpdate = ""
        root.updateQueue = []

        if (ok) {
            root.lastError = ""
            root.lastAction = "Updates bijgewerkt"
        }

        root.updateFinished(ok, ok ? root.lastAction : root.lastError)
        if (ok)
            root.refresh()
    }

    function failUpdate(message) {
        updateGuardTimer.stop()
        root.updateQueue = []
        root.pendingUpdate = ""
        root.busy = false
        root.lastError = message
        root.updateFinished(false, message)
    }

    function status() {
        return {
            checked: root.checked,
            loading: root.loading,
            busy: root.busy,
            refreshingIndex: root.fetchingIndex,
            aptAvailable: root.aptAvailable,
            flatpakAvailable: root.flatpakAvailable,
            error: root.lastError,
            lastAction: root.lastAction,
            lastUpdated: root.lastUpdated
                ? root.lastUpdated.toISOString() : null,
            updatedLabel: root.updatedLabel(),
            count: root.totalCount,
            aptCount: root.aptCount,
            flatpakCount: root.flatpakCount,
            apt: root.aptUpdates,
            flatpak: root.flatpakUpdates,
            elevate: root.elevateCommand
        }
    }

    // --- Processen --------------------------------------------------------

    // Controleer eerst welke pakketbeheerders aanwezig zijn. apt is op dit
    // systeem altijd beschikbaar; flatpak is optioneel.
    Process {
        id: availabilityProcess
        command: ["sh", "-c",
            'for b in "$@"; do if command -v -- "$b" >/dev/null 2>&1; '
                + 'then printf "%s=1\\n" "$b"; else printf "%s=0\\n" "$b"; fi; '
                + 'done',
            "updates-check", root.aptBin, root.flatpakBin]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleAvailability(text)
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.loading = false
                root.checked = true
                root.lastError = "Pakketbeheerders controleren mislukt"
                root.updated()
                return
            }
            root.startListings()
        }
    }

    // Alleen bij een expliciete verversing: eerst de APT-index bijwerken.
    // Mislukt dit (geannuleerd, geen polkit-agent of geen netwerk), dan gaat
    // de controle gewoon verder met de bestaande index.
    Process {
        id: indexProcess

        command: root.aptIndexRefreshCommand()

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.indexOutput = text
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.indexError = text
        }

        onExited: (exitCode) => {
            indexGuardTimer.stop()
            root.fetchingIndex = false

            if (exitCode !== 0 && exitCode !== 126) {
                // 126 = de pkexec-dialoog is geannuleerd; dat is geen fout.
                const detail = root.cleanError(root.indexError,
                    root.indexOutput)
                root.noteError("Pakketlijsten verversen mislukt"
                    + (detail.length > 0 ? ": " + detail : ""))
            }

            root.startPackageListings()
        }
    }

    Process {
        id: aptProcess
        command: ["env", "LC_ALL=C", root.aptBin, "list", "--upgradable"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.aptOutput = text
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.aptError = text
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.aptUpdates = root.parseApt(root.aptOutput)
            } else {
                root.aptUpdates = []
                const detail = root.cleanError(root.aptError, root.aptOutput)
                root.noteError("Systeemupdates ophalen mislukt"
                    + (detail.length > 0 ? ": " + detail : ""))
            }
            root.finishListing()
        }
    }

    Process {
        id: flatpakProcess
        command: ["env", "LC_ALL=C", root.flatpakBin, "remote-ls",
            "--updates", "--columns=application,branch,origin,version"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.flatpakOutput = text
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.flatpakError = text
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.flatpakUpdates = root.parseFlatpak(root.flatpakOutput)
            } else {
                root.flatpakUpdates = []
                const detail = root.cleanError(root.flatpakError,
                    root.flatpakOutput)
                root.noteError("Flatpak-updates ophalen mislukt"
                    + (detail.length > 0 ? ": " + detail : ""))
            }
            root.finishListing()
        }
    }

    Process {
        id: updateProcess

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateOutput = text
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateError = text
        }

        onExited: (exitCode) => {
            updateGuardTimer.stop()

            if (exitCode !== 0) {
                const detail = root.cleanError(root.updateError,
                    root.updateOutput)
                const label = root.pendingUpdate === "flatpak"
                    ? "Flatpaks bijwerken" : "Systeem bijwerken"
                root.lastError = label + " mislukt"
                    + (detail.length > 0 ? ": " + detail : "")
                root.updateFinished(false, root.lastError)
                root.busy = false
                root.pendingUpdate = ""
                root.updateQueue = []
                return
            }

            if (root.updateQueue.length > 0) {
                root.runNextUpdate()
                return
            }

            root.finishUpdate(true)
        }
    }

    // Zonder deze controle blijft `fetchingIndex` hangen als pkexec of
    // apt-get niet gestart kan worden: QProcess levert dan geen
    // exited-signaal. De tijd begint pas na het starten; een openstaande
    // pkexec-dialoog houdt het proces draaiend en is dus geen time-out.
    Timer {
        id: indexGuardTimer
        interval: 3000
        repeat: false
        running: false

        onTriggered: {
            if (!root.fetchingIndex || indexProcess.running)
                return
            root.fetchingIndex = false
            root.noteError("Pakketlijsten verversen kon niet worden gestart"
                + " (commando niet gevonden?)")
            root.startPackageListings()
        }
    }

    // Zonder deze controle blijft `busy` hangen als pkexec of flatpak niet
    // gestart kan worden: QProcess levert dan geen exited-signaal.
    Timer {
        id: updateGuardTimer
        interval: 2000
        repeat: false
        running: false

        onTriggered: {
            if (!root.busy || updateProcess.running)
                return
            root.failUpdate("Bijwerken kon niet worden gestart"
                + " (commando niet gevonden?)")
        }
    }

    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
