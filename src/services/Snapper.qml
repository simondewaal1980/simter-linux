pragma Singleton

// Snapper.qml — btrfs-momentopnamen via de snapper-CLI.
//
// De service leest configuraties met `snapper --jsonout list-configs` en
// momentopnamen met `snapper --jsonout list`. De uitvoer wordt genormaliseerd,
// zodat de widget en popup geen CLI-details hoeven te kennen.
//
// Lezen als gewone gebruiker werkt alleen als die in ALLOW_USERS/ALLOW_GROUPS
// staat en toegang heeft tot de .snapshots-map. Zonder die rechten toont de
// widget een duidelijke toegangsfout. Aanmaken en verwijderen worden in dat
// geval via pkexec uitgevoerd, zodat een polkit-agent om bevoegdheid kan
// vragen. SNAPPER_ELEVATE kan dat commando overschrijven (bijvoorbeeld
// "sudo -n", of leeg voor geen elevatie).
//
// SNAPPER_BIN en SNAPPER_CONFIG zijn bedoeld voor tests en afwijkende
// installaties; zonder die variabelen gebruikt de service `snapper` en de
// standaardconfiguratie (root).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string snapperBin: {
        const override = Quickshell.env("SNAPPER_BIN")
        if (override && override.length > 0)
            return override
        return "snapper"
    }

    readonly property string preferredConfig: {
        const override = Quickshell.env("SNAPPER_CONFIG")
        if (override && override.length > 0)
            return override
        return ""
    }

    readonly property int refreshInterval: 2 * 60 * 1000

    // Opruimen laat deze hoeveelheid momentopnamen staan. Standaard- en
    // actieve momentopnamen zijn door snapper beschermd en tellen wel mee.
    readonly property int cleanupLimit: 10

    // --- Status -----------------------------------------------------------

    property bool available: true
    property bool checked: false
    property bool loaded: false
    property bool loading: false
    property bool busy: false
    property string accessError: ""
    property string lastError: ""
    property string lastAction: ""
    property var lastUpdated: null

    property var configs: []
    property string activeConfig: ""
    property var snapshots: []

    readonly property bool hasAccess: root.loaded && root.available
        && root.accessError.length === 0
    readonly property int snapshotCount: root.snapshots.length
    readonly property var latestSnapshot: root.snapshots.length > 0
        ? root.snapshots[0] : null
    readonly property var cleanupSelection:
        root.cleanupCandidates(root.cleanupLimit)
    readonly property int cleanupCount: root.cleanupSelection.length

    readonly property var activeConfigInfo: {
        for (let i = 0; i < root.configs.length; i++) {
            if (root.configs[i].name === root.activeConfig)
                return root.configs[i]
        }
        return null
    }

    readonly property string activeSubvolume: root.activeConfigInfo
        ? root.activeConfigInfo.subvolume : ""

    // Snapper weigert rollback voor configuraties op een niet-root subvolume.
    // Zolang de subvolume onbekend is, laten we de CLI het oordeel geven.
    readonly property bool rollbackSupported: root.activeSubvolume.length === 0
        || root.activeSubvolume === "/"

    // Snapper-configuraties zijn eigendom van root en snapperd controleert
    // ALLOW_USERS. De widget kan die instelling niet zelf wijzigen; daarom
    // tonen we het eenmalige commando in de popup en via IPC.
    readonly property string currentUser: {
        const user = Quickshell.env("USER")
        if (user && user.length > 0)
            return user
        const login = Quickshell.env("LOGNAME")
        if (login && login.length > 0)
            return login
        return "$USER"
    }

    readonly property string setupConfig: root.activeConfig.length > 0
        ? root.activeConfig : "root"

    readonly property string setupCommand: "sudo snapper -c " + root.setupConfig
        + " set-config \"ALLOW_USERS=" + root.currentUser + " SYNC_ACL=yes\""

    // --- Interne processtatus --------------------------------------------

    property string pendingAction: ""
    property int pendingNumber: -1
    property var pendingNumbers: []
    property string pendingDescription: ""
    property bool pendingElevated: false
    property string actionOutput: ""
    property string actionError: ""

    property string configOutput: ""
    property string configError: ""

    property string listOutput: ""
    property string listError: ""

    signal created(int number)
    signal deleted(int number)
    signal cleaned(int count)
    signal rolledBack(int number)
    signal actionFinished(bool ok, string message)

    // --- Hulpfuncties -----------------------------------------------------

    function firstLine(value) {
        const text = String(value === null || value === undefined ? "" : value).trim()
        if (text.length === 0)
            return ""
        return text.split("\n")[0]
    }

    function cleanError(stderrText, stdoutText) {
        let detail = firstLine(stderrText)
        if (detail.length === 0)
            detail = firstLine(stdoutText)
        return detail
    }

    function isPermissionError(detail) {
        const text = String(detail || "").toLowerCase()
        return text.indexOf("toegang") >= 0
            || text.indexOf("rechten") >= 0
            || text.indexOf("bevoegdheid") >= 0
            || text.indexOf("autorisatie") >= 0
            || text.indexOf("permission") >= 0
            || text.indexOf("no_permissions") >= 0
            || text.indexOf("not permitted") >= 0
            || text.indexOf("not authorized") >= 0
            || text.indexOf("authentication") >= 0
            || text.indexOf("access denied") >= 0
            || text.indexOf("niet gemachtigd") >= 0
    }

    function isMissingBinary(detail, exitCode) {
        const text = String(detail || "").toLowerCase()
        return exitCode === 127
            || text.indexOf("niet gevonden") >= 0
            || text.indexOf("not found") >= 0
            || text.indexOf("no such file") >= 0
            || text.indexOf("execvp") >= 0
    }

    function chooseConfig() {
        let chosen = ""

        if (root.preferredConfig.length > 0)
            chosen = root.preferredConfig
        else {
            for (let i = 0; i < root.configs.length; i++) {
                if (root.configs[i].name === "root") {
                    chosen = "root"
                    break
                }
            }
        }

        if (chosen.length === 0 && root.configs.length > 0)
            chosen = root.configs[0].name

        root.activeConfig = chosen
    }

    function parseConfigs(text) {
        const result = []

        try {
            const data = JSON.parse(text)
            const items = data && Array.isArray(data.configs) ? data.configs : []
            for (let i = 0; i < items.length; i++) {
                const item = items[i]
                if (!item || typeof item.config !== "string"
                        || item.config.length === 0)
                    continue
                result.push({
                    name: item.config,
                    subvolume: typeof item.subvolume === "string"
                        ? item.subvolume : ""
                })
            }
        } catch (error) {
            return result
        }

        return result
    }

    function parseSnapshots(text) {
        let rows = []

        try {
            const data = JSON.parse(text)
            if (Array.isArray(data)) {
                rows = data
            } else if (data && typeof data === "object") {
                // Snapper levert een object met de configuratienaam als sleutel
                // en een array met momentopnamen als waarde.
                if (Array.isArray(data[root.activeConfig]))
                    rows = data[root.activeConfig]
                else {
                    const keys = Object.keys(data)
                    for (let i = 0; i < keys.length; i++) {
                        if (Array.isArray(data[keys[i]])) {
                            rows = data[keys[i]]
                            break
                        }
                    }
                }
            }
        } catch (error) {
            return null
        }

        const result = []
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i]
            if (!row)
                continue

            const number = Number(row.number)
            // 0 is de huidige toestand, geen echte momentopname.
            if (!isFinite(number) || number <= 0)
                continue

            result.push({
                number: number,
                type: typeof row.type === "string" ? row.type : "single",
                date: typeof row.date === "string" ? row.date : "",
                user: typeof row.user === "string" ? row.user : "",
                cleanup: typeof row.cleanup === "string" ? row.cleanup : "",
                description: typeof row.description === "string"
                    ? row.description : "",
                preNumber: row["pre-number"] !== null
                    && row["pre-number"] !== undefined
                    ? Number(row["pre-number"]) : -1,
                isDefault: row.default === true,
                isActive: row.active === true,
                isReadOnly: row["read-only"] === true
            })
        }

        result.sort(function(a, b) {
            return b.number - a.number
        })

        return result
    }

    // Geeft de nummers van de oudste momentopnamen die weg mogen om binnen
    // `max` momentopnamen te blijven. De lijst is nieuwste-eerst, dus alles
    // vanaf `max` is kandidaat. Standaard- en actieve momentopnamen laat
    // snapper niet verwijderen en worden hier overgeslagen.
    function cleanupCandidates(max) {
        const result = []
        const requested = Number(max)
        if (!isFinite(requested) || requested < 0)
            return result

        const limit = Math.floor(requested)
        for (let i = limit; i < root.snapshots.length; i++) {
            const snapshot = root.snapshots[i]
            if (!snapshot || snapshot.isDefault || snapshot.isActive)
                continue
            result.push(snapshot.number)
        }
        return result
    }

    function typeLabel(type) {
        if (type === "pre")
            return "Pre"
        if (type === "post")
            return "Post"
        return "Single"
    }

    function cleanupLabel(cleanup) {
        if (cleanup === "number")
            return "getal"
        if (cleanup === "timeline")
            return "tijdlijn"
        if (cleanup === "empty-pre-post")
            return "leeg"
        return cleanup
    }

    function dateLabel(value, short) {
        if (!value)
            return "—"

        const date = new Date(value)
        if (isNaN(date.getTime()))
            return String(value)

        const pattern = short ? "d MMM HH:mm" : "d MMM yyyy HH:mm"
        return date.toLocaleString(Qt.locale("nl_NL"), pattern)
    }

    function updatedLabel() {
        if (root.lastUpdated === null)
            return "nooit"
        return root.lastUpdated.toLocaleString(Qt.locale("nl_NL"), "HH:mm")
    }

    // --- Configuraties en momentopnamen ----------------------------------

    function checkBinary() {
        if (checkProcess.running)
            return
        root.loading = true
        checkProcess.running = true
    }

    function refresh() {
        if (root.busy)
            return
        if (!root.checked) {
            root.checkBinary()
            return
        }
        if (configProcess.running || listProcess.running)
            return

        if (root.configs.length === 0)
            root.refreshConfigs()
        else
            root.refreshSnapshots()
    }

    function refreshConfigs() {
        if (configProcess.running || root.busy)
            return

        root.loading = true
        root.configOutput = ""
        root.configError = ""
        configProcess.running = true
    }

    function refreshSnapshots() {
        if (listProcess.running || root.busy)
            return
        if (root.activeConfig.length === 0)
            return

        root.loading = true
        root.listOutput = ""
        root.listError = ""
        listProcess.command = [
            root.snapperBin,
            "--jsonout",
            "--iso",
            "--config", root.activeConfig,
            "list",
            "--columns",
            "subvolume,number,default,active,type,pre-number,date,user,cleanup,description"
        ]
        listProcess.running = true
    }

    function selectConfig(name) {
        if (root.busy)
            return false
        if (!name || name === root.activeConfig)
            return name === root.activeConfig

        let found = false
        for (let i = 0; i < root.configs.length; i++) {
            if (root.configs[i].name === name) {
                found = true
                break
            }
        }
        if (!found)
            return false

        root.activeConfig = name
        root.snapshots = []
        root.accessError = ""
        root.lastError = ""
        root.lastAction = ""
        root.lastUpdated = null
        root.refreshSnapshots()
        return true
    }

    // --- Acties -----------------------------------------------------------

    function elevationPrefix() {
        const override = Quickshell.env("SNAPPER_ELEVATE")
        const value = override === undefined || override === null
            ? "pkexec" : String(override).trim()
        return value.length > 0 ? value.split(/\s+/) : []
    }

    function commandForAction(args, elevate) {
        const useElevation = typeof elevate === "boolean"
            ? elevate : !root.hasAccess
        if (!useElevation)
            return [root.snapperBin].concat(args)
        return root.elevationPrefix().concat([root.snapperBin], args)
    }

    function create(description) {
        if (root.busy || !root.available || root.activeConfig.length === 0)
            return false

        const desc = String(description === null || description === undefined
            ? "" : description).trim()

        root.busy = true
        root.lastError = ""
        root.lastAction = ""
        root.actionOutput = ""
        root.actionError = ""
        root.pendingAction = "create"
        root.pendingNumber = -1
        root.pendingNumbers = []
        root.pendingDescription = desc
        root.pendingElevated = !root.hasAccess

        const args = ["--config", root.activeConfig, "create", "--print-number"]
        if (desc.length > 0)
            args.push("--description", desc)

        actionProcess.command = root.commandForAction(args)
        actionProcess.running = true
        actionGuardTimer.restart()
        return true
    }

    function remove(number) {
        const value = Number(number)
        if (root.busy || !root.available || root.activeConfig.length === 0)
            return false
        if (!isFinite(value) || value <= 0)
            return false

        root.busy = true
        root.lastError = ""
        root.lastAction = ""
        root.actionOutput = ""
        root.actionError = ""
        root.pendingAction = "delete"
        root.pendingNumber = value
        root.pendingNumbers = []
        root.pendingDescription = ""
        root.pendingElevated = !root.hasAccess

        actionProcess.command = root.commandForAction([
            "--config", root.activeConfig, "delete", "--sync", String(value)
        ])
        actionProcess.running = true
        actionGuardTimer.restart()
        return true
    }

    // Verwijdert de oudste momentopnamen tot er maximaal `max` overblijven.
    // De selectie komt uit cleanupCandidates(), zodat standaard- en actieve
    // momentopnamen nooit worden meegestuurd.
    function cleanup(max) {
        if (root.busy || !root.available || root.activeConfig.length === 0)
            return false

        const requested = (max === undefined || max === null)
            ? root.cleanupLimit : Number(max)
        if (!isFinite(requested) || requested < 0)
            return false

        const limit = Math.floor(requested)
        const numbers = root.cleanupCandidates(limit)

        if (numbers.length === 0) {
            const message = "Niets op te ruimen (max " + limit + ")"
            root.lastError = ""
            root.lastAction = message
            root.actionFinished(true, message)
            return false
        }

        root.busy = true
        root.lastError = ""
        root.lastAction = ""
        root.actionOutput = ""
        root.actionError = ""
        root.pendingAction = "cleanup"
        root.pendingNumber = limit
        root.pendingNumbers = numbers
        root.pendingDescription = ""
        root.pendingElevated = !root.hasAccess

        const args = ["--config", root.activeConfig, "delete", "--sync"]
        for (let i = 0; i < numbers.length; i++)
            args.push(String(numbers[i]))

        actionProcess.command = root.commandForAction(args)
        actionProcess.running = true
        actionGuardTimer.restart()
        return true
    }

    function startRollback(elevated) {
        root.pendingElevated = elevated
        root.actionOutput = ""
        root.actionError = ""
        actionProcess.command = root.commandForAction([
            "--config", root.activeConfig,
            "rollback", "--print-number", String(root.pendingNumber)
        ], elevated)
        actionProcess.running = true
        actionGuardTimer.restart()
    }

    // Rollback maakt nieuwe momentopnamen en wijzigt de standaard-subvolume;
    // de wijziging wordt pas actief na een herstart. Als de eerste poging
    // zonder elevatie op rechten stuit, probeert finishAction het eenmalig
    // opnieuw via pkexec/SNAPPER_ELEVATE.
    function rollback(number) {
        const value = Number(number)
        if (root.busy || !root.available || root.activeConfig.length === 0)
            return false
        if (!root.rollbackSupported || !isFinite(value) || value <= 0)
            return false

        root.busy = true
        root.lastError = ""
        root.lastAction = ""
        root.actionOutput = ""
        root.actionError = ""
        root.pendingAction = "rollback"
        root.pendingNumber = value
        root.pendingNumbers = []
        root.pendingDescription = ""
        root.pendingElevated = !root.hasAccess

        root.startRollback(!root.hasAccess)
        return true
    }

    function finishAction(exitCode) {
        actionGuardTimer.stop()
        const action = root.pendingAction
        const number = root.pendingNumber
        const count = root.pendingNumbers.length
        const detail = root.cleanError(root.actionError, root.actionOutput)

        // Rollback is normaal gesproken een root-actie. Lukt de directe
        // poging niet door rechten, probeer het dan eenmalig met elevatie.
        if (exitCode !== 0 && action === "rollback"
                && !root.pendingElevated && root.isPermissionError(detail)) {
            root.startRollback(true)
            return
        }

        root.busy = false
        root.pendingAction = ""
        root.pendingNumber = -1
        root.pendingNumbers = []
        root.pendingDescription = ""
        root.pendingElevated = false

        if (exitCode === 0) {
            let message = ""

            if (action === "create") {
                const match = root.actionOutput.trim().match(/(\d+)/)
                const createdNumber = match ? parseInt(match[1], 10) : -1
                message = createdNumber > 0
                    ? "Momentopname #" + createdNumber + " aangemaakt"
                    : "Momentopname aangemaakt"
                root.lastAction = message
                if (createdNumber > 0)
                    root.created(createdNumber)
            } else if (action === "delete") {
                message = "Momentopname #" + number + " verwijderd"
                root.lastAction = message
                root.deleted(number)
            } else if (action === "cleanup") {
                message = count + (count === 1
                    ? " momentopname opgeruimd (max " : " momentopnamen opgeruimd (max ")
                    + number + ")"
                root.lastAction = message
                root.cleaned(count)
            } else if (action === "rollback") {
                const match = root.actionOutput.trim().match(/(\d+)/)
                const newNumber = match ? parseInt(match[1], 10) : -1
                message = "Rollback naar #" + number + " voorbereid"
                    + (newNumber > 0
                        ? " (nieuwe momentopname #" + newNumber + ")" : "")
                    + " — herstart om te activeren"
                root.lastAction = message
                root.rolledBack(number)
            } else {
                message = "Actie voltooid"
                root.lastAction = message
            }

            root.lastError = ""
            root.actionFinished(true, message)
            root.refreshSnapshots()
            return
        }

        let message = detail.length > 0
            ? detail
            : "Snapper-actie mislukt (exit " + exitCode + ")"
        if (root.isPermissionError(message))
            message = "Geen bevoegdheid voor deze actie: " + message

        root.lastError = message
        root.actionFinished(false, message)
    }

    function status() {
        return {
            available: root.available,
            loaded: root.loaded,
            loading: root.loading,
            busy: root.busy,
            hasAccess: root.hasAccess,
            accessError: root.accessError,
            error: root.lastError,
            lastAction: root.lastAction,
            lastUpdated: root.lastUpdated
                ? root.lastUpdated.toISOString() : null,
            updatedLabel: root.updatedLabel(),
            activeConfig: root.activeConfig,
            subvolume: root.activeSubvolume,
            rollbackSupported: root.rollbackSupported,
            configs: root.configs,
            count: root.snapshotCount,
            cleanupLimit: root.cleanupLimit,
            cleanupCount: root.cleanupCount,
            snapshots: root.snapshots,
            bin: root.snapperBin,
            elevate: root.elevationPrefix().join(" "),
            setupCommand: root.setupCommand
        }
    }

    // --- Processen --------------------------------------------------------

    // Controleer eerst of het programma bestaat. QProcess levert bij een
    // onbekend commando geen `exited`-signaal; zonder deze controle bleef de
    // widget in de laadtoestand hangen.
    Process {
        id: checkProcess
        command: ["sh", "-c", 'command -v -- "$1" >/dev/null 2>&1',
            "snapper-check", root.snapperBin]

        onExited: (exitCode) => {
            root.checked = true
            if (exitCode !== 0) {
                root.available = false
                root.loaded = true
                root.loading = false
                root.accessError = ""
                root.lastError = "snapper is niet gevonden. Installeer het snapper-pakket."
                root.snapshots = []
                return
            }

            root.available = true
            root.refreshConfigs()
        }
    }

    Process {
        id: configProcess
        command: [root.snapperBin, "--jsonout", "list-configs"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.configOutput = text
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.configError = text
        }

        onExited: (exitCode) => {
            root.loading = false
            const detail = root.cleanError(root.configError, root.configOutput)

            if (exitCode !== 0) {
                // Met een expliciete SNAPPER_CONFIG kunnen we het toch
                // proberen, ook als list-configs (nog) niet leesbaar is.
                if (root.preferredConfig.length > 0) {
                    root.configs = [{
                        name: root.preferredConfig,
                        subvolume: ""
                    }]
                    root.activeConfig = root.preferredConfig
                    root.loaded = true
                    root.available = !root.isMissingBinary(detail, exitCode)
                    root.lastError = root.available ? "" : "snapper is niet gevonden"
                    root.refreshSnapshots()
                    return
                }

                root.loaded = true
                root.available = !root.isMissingBinary(detail, exitCode)
                root.accessError = ""
                root.lastError = root.available
                    ? "Snapper-configuraties ophalen mislukt"
                        + (detail.length > 0 ? ": " + detail : "")
                    : "snapper is niet gevonden. Installeer het snapper-pakket."
                return
            }

            root.configs = root.parseConfigs(root.configOutput)
            root.loaded = true
            root.available = true
            root.accessError = ""
            root.lastError = ""

            if (root.configs.length === 0) {
                if (root.preferredConfig.length > 0) {
                    root.configs = [{
                        name: root.preferredConfig,
                        subvolume: ""
                    }]
                    root.activeConfig = root.preferredConfig
                    root.refreshSnapshots()
                } else {
                    root.lastError = "Geen snapper-configuraties gevonden"
                }
                return
            }

            root.chooseConfig()
            root.refreshSnapshots()
        }
    }

    Process {
        id: listProcess

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.listOutput = text
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.listError = text
        }

        onExited: (exitCode) => {
            root.loading = false
            const detail = root.cleanError(root.listError, root.listOutput)

            if (exitCode !== 0) {
                root.loaded = true

                if (root.isPermissionError(detail)) {
                    root.available = true
                    root.accessError = "Geen toegang tot snapper-configuratie '"
                        + root.activeConfig + "'"
                    root.lastError = ""
                    root.snapshots = []
                    return
                }

                if (root.isMissingBinary(detail, exitCode)) {
                    root.available = false
                    root.accessError = ""
                    root.lastError = "snapper is niet gevonden. Installeer het snapper-pakket."
                    root.snapshots = []
                    return
                }

                root.available = true
                root.accessError = ""
                root.lastError = "Momentopnamen ophalen mislukt"
                    + (detail.length > 0 ? ": " + detail : "")
                return
            }

            const parsed = root.parseSnapshots(root.listOutput)
            if (parsed === null) {
                root.available = true
                root.loaded = true
                root.accessError = ""
                root.lastError = "Onleesbare uitvoer van snapper list"
                return
            }

            root.available = true
            root.loaded = true
            root.accessError = ""
            root.lastError = ""
            root.snapshots = parsed
            root.lastUpdated = new Date()
        }
    }

    Process {
        id: actionProcess

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.actionOutput = text
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.actionError = text
        }

        onExited: (exitCode) => root.finishAction(exitCode)
    }

    // QProcess levert bij een commando dat niet gestart kan worden geen
    // exited-signaal. Deze korte controle voorkomt dat `busy` blijft hangen
    // wanneer bijvoorbeeld pkexec ontbreekt.
    Timer {
        id: actionGuardTimer
        interval: 1500
        repeat: false
        running: false

        onTriggered: {
            if (!root.busy || actionProcess.running)
                return

            const message = "Snapper-actie kon niet worden gestart"
                + " (commando niet gevonden?)"
            root.busy = false
            root.pendingAction = ""
            root.pendingNumber = -1
            root.pendingNumbers = []
            root.pendingDescription = ""
            root.pendingElevated = false
            root.lastError = message
            root.actionFinished(false, message)
        }
    }

    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.checkBinary()
}
