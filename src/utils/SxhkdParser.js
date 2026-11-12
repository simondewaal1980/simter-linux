.pragma library

// SxhkdParser.js — leest een sxhkdrc en maakt er een doorzoekbare lijst van.
//
// Conventies in de sxhkdrc (zie ook de kop van config/sxhkd/sxhkdrc):
//   - een comment direct boven een hotkey is de omschrijving;
//   - "# --- Sectie ---" begint een groep;
//   - ingesprongen regels onder een hotkey zijn het commando;
//   - een regel die op \ eindigt loopt door op de volgende regel.
//
// Daarnaast worden de sxhkd-syntaxregels ondersteund die in dit project
// voorkomen: chord-chains met ; of :, brace-expansie {a,b} (in hotkey én
// commando, parallel uitgevoerd als de groepen even groot zijn), en
// bereik-expansie {1-9}/{a-z}. De underscore staat voor een lege optie.
//
// De parser is bewust een pure functie zonder QML-afhankelijkheden, zodat
// ShortcutsWindow.qml hem ook via IPC kan laten testen.

function isBlank(line) {
    return line === null || line === undefined || String(line).trim().length === 0
}

function isComment(line) {
    return String(line).replace(/^\s+/, "").charAt(0) === "#"
}

function isIndented(line) {
    return /^\s/.test(String(line)) && !isBlank(line)
}

// Commenttekst zonder # en omringende spaties.
function commentText(line) {
    return String(line).replace(/^\s*#\s?/, "").trim()
}

// "# --- Sectie ---" (minimaal twee streepjes aan beide kanten).
function sectionTitle(line) {
    const match = String(line).match(/^\s*#\s*-{2,}\s*(.+?)\s*-{2,}\s*$/)
    return match ? match[1].trim() : ""
}

// Splitst tekst op scheidingstekens die niet binnen brace-groepen staan.
function splitTopLevel(text, separators) {
    const parts = []
    var current = ""
    var depth = 0
    var escaped = false

    for (var i = 0; i < text.length; i++) {
        const character = text.charAt(i)

        if (escaped) {
            current += character
            escaped = false
            continue
        }
        if (character === "\\") {
            current += character
            escaped = true
            continue
        }
        if (character === "{") {
            depth++
            current += character
            continue
        }
        if (character === "}") {
            if (depth > 0)
                depth--
            current += character
            continue
        }
        if (depth === 0 && separators.indexOf(character) >= 0) {
            parts.push(current)
            current = ""
            continue
        }
        current += character
    }

    parts.push(current)
    return parts
}

// Vindt de buitenste brace-groepen en hun positie in de tekst.
function findGroups(text) {
    const groups = []
    var depth = 0
    var start = -1

    for (var i = 0; i < text.length; i++) {
        const character = text.charAt(i)
        if (character === "{" && depth === 0) {
            start = i
            depth = 1
        } else if (character === "{" && depth > 0) {
            depth++
        } else if (character === "}" && depth > 0) {
            depth--
            if (depth === 0) {
                groups.push({
                    start: start,
                    end: i,
                    body: text.substring(start + 1, i)
                })
                start = -1
            }
        }
    }

    return groups
}

function expandRange(option) {
    const numeric = option.match(/^([0-9]+)-([0-9]+)$/)
    if (numeric) {
        const first = parseInt(numeric[1], 10)
        const last = parseInt(numeric[2], 10)
        if (first > last || last - first > 512)
            return null
        const values = []
        for (var n = first; n <= last; n++)
            values.push(String(n))
        return values
    }

    const alpha = option.match(/^([A-Za-z])-([A-Za-z])$/)
    if (alpha) {
        const firstCode = alpha[1].charCodeAt(0)
        const lastCode = alpha[2].charCodeAt(0)
        if (firstCode > lastCode || lastCode - firstCode > 128)
            return null
        const values = []
        for (var c = firstCode; c <= lastCode; c++)
            values.push(String.fromCharCode(c))
        return values
    }

    return null
}

function optionList(body) {
    const raw = splitTopLevel(body, [","])
    const options = []

    for (var i = 0; i < raw.length; i++) {
        const option = raw[i].trim()
        if (option === "_") {
            options.push("")
            continue
        }
        const range = expandRange(option)
        if (range !== null) {
            for (var j = 0; j < range.length; j++)
                options.push(range[j])
        } else {
            options.push(option)
        }
    }

    if (options.length === 0)
        options.push("")
    return options
}

// Alle indexcombinaties voor de brace-groepen, in leesorde.
function cartesian(groups) {
    var tuples = [[]]
    for (var i = 0; i < groups.length; i++) {
        const next = []
        const options = groups[i].options
        for (var t = 0; t < tuples.length; t++) {
            for (var o = 0; o < options.length; o++)
                next.push(tuples[t].concat([o]))
        }
        tuples = next
    }
    return tuples
}

function applyTuple(text, groups, tuple) {
    var result = text
    for (var i = groups.length - 1; i >= 0; i--) {
        const group = groups[i]
        const options = group.options
        const index = tuple.length > i
            ? Math.min(tuple[i], options.length - 1) : 0
        result = result.substring(0, group.start)
            + options[index]
            + result.substring(group.end + 1)
    }
    return result
}

function tokenLabel(token) {
    const lower = token.toLowerCase()
    const names = {
        "super": "Super",
        "mod4": "Super",
        "hyper": "Hyper",
        "meta": "Meta",
        "alt": "Alt",
        "mod1": "Alt",
        "ctrl": "Ctrl",
        "control": "Ctrl",
        "shift": "Shift",
        "mode_switch": "Mode_switch",
        "lock": "Lock",
        "mod2": "Mod2",
        "mod3": "Mod3",
        "mod5": "Mod5",
        "return": "Return",
        "enter": "Return",
        "tab": "Tab",
        "escape": "Escape",
        "esc": "Escape",
        "space": "Space",
        "backspace": "Backspace",
        "delete": "Delete",
        "insert": "Insert",
        "home": "Home",
        "end": "End",
        "page_up": "PageUp",
        "page_down": "PageDown",
        "up": "↑",
        "down": "↓",
        "left": "←",
        "right": "→",
        "print": "Print",
        "menu": "Menu",
        "comma": ",",
        "period": ".",
        "slash": "/",
        "backslash": "\\",
        "minus": "-",
        "equal": "=",
        "grave": "`",
        "bracketleft": "[",
        "bracketright": "]",
        "semicolon": ";",
        "apostrophe": "'"
    }

    if (names[lower])
        return names[lower]

    // @ (release) en ~ (replay) horen bij het gedrag, niet bij de toetsnaam.
    var prefix = ""
    var name = token
    while (name.length > 0 && (name.charAt(0) === "@" || name.charAt(0) === "~")) {
        if (name.charAt(0) === "@")
            prefix += "@"
        else
            prefix += "~"
        name = name.substring(1)
    }

    var label = name
    if (name.length === 1)
        label = name.toUpperCase()
    else if (name.toLowerCase().indexOf("xf86") === 0)
        label = name.toUpperCase().replace("XF86", "XF86")
    else if (name.length > 0)
        label = name.charAt(0).toUpperCase() + name.substring(1)

    return prefix + label
}

// Zet een uitgeklapte hotkey om in losse chords met toetslabels.
// "super + h ; shift + l" -> [["Super", "H"], ["Shift", "L"]]
function parseChords(expandedKey) {
    const chordTexts = splitTopLevel(expandedKey, [";", ":"])
    const chords = []

    for (var i = 0; i < chordTexts.length; i++) {
        const chordText = chordTexts[i].trim()
        if (chordText.length === 0)
            continue

        const rawTokens = splitTopLevel(chordText, ["+"])
        const tokens = []
        for (var j = 0; j < rawTokens.length; j++) {
            const token = rawTokens[j].trim()
            if (token.length > 0)
                tokens.push(tokenLabel(token))
        }
        if (tokens.length > 0)
            chords.push(tokens)
    }

    return chords
}

function displayKey(chords) {
    const parts = []
    for (var i = 0; i < chords.length; i++)
        parts.push(chords[i].join("+"))
    return parts.join(" ; ")
}

// --- Eigen sneltoetsen -------------------------------------------------
//
// ShortcutsWindow schrijft eigen bindingen in hetzelfde sxhkdrc-bestand,
// tussen twee marker-comments:
//
//   # @qs-shortcut {"id":"qs-…","group":"Eigen sneltoetsen"}
//   # Omschrijving
//   super + shift + e
//       alacritty -e htop
//   # @qs-shortcut-end qs-…
//
// De markers zijn comments voor sxhkd en worden door de parser uit de
// omschrijving gefilterd. Zo blijft de sxhkdrc de enige bron en kan de UI
// precies haar eigen blokken terugvinden zonder handmatige regels te raken.

var MODIFIER_ORDER = {
    "super": 0,
    "ctrl": 1,
    "alt": 2,
    "shift": 3
}

var CUSTOM_GROUP = "Eigen sneltoetsen"

function canonicalKeyName(token) {
    const lower = token.toLowerCase()
    const names = {
        "super": "super",
        "mod4": "super",
        "ctrl": "ctrl",
        "control": "ctrl",
        "alt": "alt",
        "mod1": "alt",
        "shift": "shift",
        "return": "Return",
        "enter": "Return",
        "tab": "Tab",
        "escape": "Escape",
        "esc": "Escape",
        "space": "space",
        "backspace": "Backspace",
        "delete": "Delete",
        "insert": "Insert",
        "home": "Home",
        "end": "End",
        "page_up": "Page_Up",
        "pageup": "Page_Up",
        "page_down": "Page_Down",
        "pagedown": "Page_Down",
        "up": "Up",
        "down": "Down",
        "left": "Left",
        "right": "Right",
        "print": "Print",
        "menu": "Menu",
        "minus": "minus",
        "equal": "equal",
        "comma": "comma",
        "period": "period",
        "slash": "slash",
        "backslash": "backslash",
        "grave": "grave",
        "bracketleft": "bracketleft",
        "bracketright": "bracketright",
        "semicolon": "semicolon",
        "apostrophe": "apostrophe",
        "plus": "plus",
        "underscore": "underscore"
    }

    if (names[lower])
        return names[lower]

    // Veelgebruikte leestekens mogen gewoon als teken worden getypt.
    const punctuation = {
        "/": "slash",
        "-": "minus",
        "=": "equal",
        ",": "comma",
        ".": "period",
        "\\": "backslash",
        "[": "bracketleft",
        "]": "bracketright",
        "'": "apostrophe",
        "`": "grave",
        "_": "underscore"
    }
    if (punctuation[token])
        return punctuation[token]

    if (/^f([1-9]|1[0-2])$/.test(lower))
        return lower.toUpperCase()
    if (/^xf86/.test(lower))
        return "XF86" + token.substring(4)
    if (token.length === 1)
        return lower
    return token
}

// Maakt van vrije invoer ("Super + Shift + X") de sxhkd-notatie
// ("super + shift + x"). Onbekende namen blijven staan, zodat brace-
// expansies en XF86-toetsen bruikbaar blijven.
function normalizeKeys(raw) {
    const text = String(raw === null || raw === undefined ? "" : raw).trim()
    if (text.length === 0)
        return ""

    const chordTexts = splitTopLevel(text, [";", ":"])
    const chords = []

    for (var c = 0; c < chordTexts.length; c++) {
        const chordText = chordTexts[c].trim()
        if (chordText.length === 0)
            continue

        const rawTokens = splitTopLevel(chordText, ["+"])
        const modifiers = []
        const keys = []

        for (var t = 0; t < rawTokens.length; t++) {
            const token = rawTokens[t].trim()
            if (token.length === 0)
                continue
            const name = canonicalKeyName(token)
            const lower = name.toLowerCase()
            if (token.charAt(0) !== "{" && MODIFIER_ORDER[lower] !== undefined)
                modifiers.push(name)
            else
                keys.push(name)
        }

        if (modifiers.length === 0 && keys.length === 0)
            continue

        modifiers.sort(function (a, b) {
            return MODIFIER_ORDER[a.toLowerCase()] - MODIFIER_ORDER[b.toLowerCase()]
        })
        chords.push(modifiers.concat(keys).join(" + "))
    }

    return chords.join(" ; ")
}

function validateKeys(raw) {
    const keys = normalizeKeys(raw)
    if (keys.length === 0)
        return { ok: false, keys: "", error: "Vul een toetscombinatie in" }

    const chordTexts = splitTopLevel(keys, [";", ":"])
    var chordCount = 0

    for (var c = 0; c < chordTexts.length; c++) {
        const chordText = chordTexts[c].trim()
        if (chordText.length === 0)
            continue

        const tokens = splitTopLevel(chordText, ["+"])
        var keyCount = 0

        for (var t = 0; t < tokens.length; t++) {
            const token = tokens[t].trim()
            if (token.length === 0)
                return { ok: false, keys: "", error: "Er staat een lege toets in de combinatie" }

            const bare = token.replace(/^[~@]+/, "")
            if (bare.length === 0)
                return { ok: false, keys: "", error: "Ongeldige toets “" + token + "”" }

            if (bare.charAt(0) === "{") {
                if (bare.charAt(bare.length - 1) !== "}")
                    return { ok: false, keys: "", error: "Een brace-groep is niet gesloten" }
                keyCount++
                continue
            }

            if (!/^[A-Za-z0-9_]+$/.test(bare))
                return { ok: false, keys: "", error: "Ongeldige toets “" + token + "”" }

            if (MODIFIER_ORDER[bare.toLowerCase()] === undefined)
                keyCount++
        }

        if (keyCount === 0)
            return { ok: false, keys: "", error: "Een combinatie heeft minstens één gewone toets nodig" }
        chordCount++
    }

    if (chordCount === 0)
        return { ok: false, keys: "", error: "Vul een toetscombinatie in" }

    return { ok: true, keys: keys, error: "" }
}

// Vergelijkt toetsen onafhankelijk van spaties en hoofdletters.
function keySignature(keys) {
    return String(keys === null || keys === undefined ? "" : keys)
        .toLowerCase().replace(/\s+/g, "")
}

// Alle concrete combinaties die een hotkey met brace-expansie oplevert,
// als genormaliseerde signaturen. Nodig om dubbele bindingen te detecteren
// voordat sxhkd ze allebei grabbt.
function keySignatures(raw) {
    const keys = normalizeKeys(raw)
    if (keys.length === 0)
        return []

    const groupsRaw = findGroups(keys)
    const groups = []
    for (var i = 0; i < groupsRaw.length; i++) {
        groups.push({
            start: groupsRaw[i].start,
            end: groupsRaw[i].end,
            options: optionList(groupsRaw[i].body)
        })
    }

    const tuples = cartesian(groups)
    const result = []
    for (var t = 0; t < tuples.length; t++) {
        const expanded = applyTuple(keys, groups, tuples[t])
        const signature = keySignature(expanded)
        if (result.indexOf(signature) < 0)
            result.push(signature)
    }
    return result
}

function canonicalModifier(token) {
    const lower = String(token).trim().toLowerCase()
    if (lower === "mod4")
        return "super"
    if (lower === "control")
        return "ctrl"
    if (lower === "mod1")
        return "alt"
    return lower
}

// Schakelt één modifier in de eerste chord en past die keuze op alle chords
// toe. Brace-groepen blijven intact omdat er brace-bewust gesplitst wordt.
function toggleModifier(raw, name) {
    const order = ["super", "ctrl", "alt", "shift"]
    const text = String(raw === null || raw === undefined ? "" : raw).trim()
    if (text.length === 0)
        return name

    const chordTexts = splitTopLevel(text, [";", ":"])
    const firstTokens = splitTopLevel(chordTexts[0], ["+"])
    var add = true
    for (var f = 0; f < firstTokens.length; f++) {
        if (canonicalModifier(firstTokens[f]) === name) {
            add = false
            break
        }
    }

    const chords = []
    for (var c = 0; c < chordTexts.length; c++) {
        const chordText = chordTexts[c].trim()
        if (chordText.length === 0)
            continue

        const tokens = splitTopLevel(chordText, ["+"])
        const modifiers = []
        const keys = []

        for (var t = 0; t < tokens.length; t++) {
            const token = tokens[t].trim()
            if (token.length === 0)
                continue
            const canonical = canonicalModifier(token)
            if (token.charAt(0) !== "{" && order.indexOf(canonical) >= 0) {
                if (!(add === false && canonical === name))
                    modifiers.push(canonical === name ? name : canonical)
            } else {
                keys.push(token)
            }
        }

        if (add && modifiers.indexOf(name) < 0)
            modifiers.push(name)

        modifiers.sort(function (a, b) {
            return order.indexOf(a) - order.indexOf(b)
        })
        chords.push(modifiers.concat(keys).join(" + "))
    }

    return chords.join(" ; ")
}

function generateId() {
    return "qs-" + Date.now().toString(36) + "-"
        + Math.floor(Math.random() * 1679616).toString(36)
}

function parseCustomMeta(line) {
    const match = String(line).match(/^\s*#\s*@qs-shortcut\s+(\{.*\})\s*$/)
    if (!match)
        return null
    try {
        const data = JSON.parse(match[1])
        if (data && typeof data.id === "string" && data.id.length > 0)
            return data
    } catch (error) {
        return null
    }
    return null
}

function isCustomEnd(line) {
    return /^\s*#\s*@qs-shortcut-end\b/.test(String(line))
}

function findCustomBlock(lines, id) {
    var start = -1
    for (var i = 0; i < lines.length; i++) {
        const meta = parseCustomMeta(lines[i])
        if (meta && meta.id === id) {
            start = i
            break
        }
    }
    if (start < 0)
        return null

    for (var end = start + 1; end < lines.length; end++) {
        if (isCustomEnd(lines[end]) && String(lines[end]).indexOf(id) >= 0)
            return { start: start, end: end }
    }
    return null
}

function cleanLines(text) {
    const lines = String(text === null || text === undefined ? "" : text)
        .split(/\r?\n/)
    while (lines.length > 0 && lines[lines.length - 1].trim().length === 0)
        lines.pop()
    return lines
}

function customBlockLines(id, group, description, keys, command) {
    const lines = []
    lines.push("# @qs-shortcut " + JSON.stringify({ id: id, group: group }))
    if (description.length > 0)
        lines.push("# " + description.replace(/\r?\n/g, " ").trim())
    lines.push(keys)

    const commandLines = command.split(/\r?\n/)
    for (var i = 0; i < commandLines.length; i++)
        lines.push("\t" + commandLines[i].trim())

    lines.push("# @qs-shortcut-end " + id)
    return lines
}

// Voegt een eigen binding toe of vervangt hem op id. Het blok wordt achteraan
// het bestand gezet; handmatige regels en secties blijven onaangeroerd.
function upsertCustomShortcut(text, entry) {
    const checked = validateKeys(entry.keys)
    if (!checked.ok)
        return { ok: false, error: checked.error, id: "", text: String(text || "") }

    const command = String(entry.command === null || entry.command === undefined
        ? "" : entry.command).trim()
    if (command.length === 0)
        return { ok: false, error: "Vul een commando in", id: "", text: String(text || "") }

    const description = String(entry.description === null || entry.description === undefined
        ? "" : entry.description).trim()
    const group = String(entry.group === null || entry.group === undefined
        ? "" : entry.group).replace(/\r?\n/g, " ").trim() || CUSTOM_GROUP
    const id = String(entry.id === null || entry.id === undefined
        ? "" : entry.id).trim() || generateId()

    const lines = String(text === null || text === undefined ? "" : text).split(/\r?\n/)
    const block = findCustomBlock(lines, id)
    if (block)
        lines.splice(block.start, block.end - block.start + 1)

    while (lines.length > 0 && lines[lines.length - 1].trim().length === 0)
        lines.pop()
    if (lines.length > 0)
        lines.push("")

    const blockLines = customBlockLines(id, group, description,
        checked.keys, command)
    for (var i = 0; i < blockLines.length; i++)
        lines.push(blockLines[i])

    return { ok: true, error: "", id: id, text: lines.join("\n") + "\n" }
}

function removeCustomShortcut(text, id) {
    const source = String(text === null || text === undefined ? "" : text)
    const lines = source.split(/\r?\n/)
    const block = findCustomBlock(lines, String(id))
    if (!block)
        return { ok: false, error: "Sneltoets niet gevonden", id: String(id), text: source }

    lines.splice(block.start, block.end - block.start + 1)

    // Hooguit één lege regel overlaten waar het blok stond.
    while (block.start > 0 && block.start < lines.length
            && lines[block.start].trim().length === 0
            && lines[block.start - 1].trim().length === 0)
        lines.splice(block.start, 1)

    const result = cleanLines(lines.join("\n"))
    return {
        ok: true,
        error: "",
        id: String(id),
        text: result.length > 0 ? result.join("\n") + "\n" : ""
    }
}

// Leest één of meer ingesprongen commandoregels, inclusief \-continuties.
function readCommands(lines, startIndex) {
    const commands = []
    var current = ""
    var index = startIndex

    while (index < lines.length) {
        const line = lines[index]
        if (isBlank(line) || !isIndented(line))
            break

        var text = String(line).trim()
        if (text.length > 0 && text.charAt(text.length - 1) === "\\") {
            current += text.substring(0, text.length - 1).trim() + " "
            index++
            continue
        }

        current += text
        if (current.length > 0)
            commands.push(current)
        current = ""
        index++
    }

    if (current.length > 0)
        commands.push(current)

    return { commands: commands, next: index }
}

function expandEntry(keyText, commandText, section, description, lineNumber, meta) {
    const keyGroupsRaw = findGroups(keyText)
    const keyGroups = []
    for (var i = 0; i < keyGroupsRaw.length; i++) {
        keyGroups.push({
            start: keyGroupsRaw[i].start,
            end: keyGroupsRaw[i].end,
            options: optionList(keyGroupsRaw[i].body)
        })
    }

    const commandGroupsRaw = findGroups(commandText)
    const commandGroups = []
    for (var j = 0; j < commandGroupsRaw.length; j++) {
        commandGroups.push({
            start: commandGroupsRaw[j].start,
            end: commandGroupsRaw[j].end,
            options: optionList(commandGroupsRaw[j].body)
        })
    }

    const tuples = cartesian(keyGroups)
    const entries = []

    for (var t = 0; t < tuples.length; t++) {
        const tuple = tuples[t]
        const expandedKey = applyTuple(keyText, keyGroups, tuple)
        // Bij even grote groepen lopen hotkey en commando parallel (h -> west).
        // Wijkt de commando-expansie af, dan gebruikt applyTuple dezelfde
        // index waar mogelijk; dat is voor afwijkende configs de beste gok.
        const expandedCommand = commandGroups.length > 0
            ? applyTuple(commandText, commandGroups, tuple)
            : commandText
        const chords = parseChords(expandedKey)

        if (chords.length === 0)
            continue

        const key = displayKey(chords)
        const custom = !!(meta && typeof meta.id === "string"
            && meta.id.length > 0)
        const group = custom && typeof meta.group === "string"
            && meta.group.length > 0 ? meta.group : section
        entries.push({
            group: group,
            description: description,
            key: key,
            chords: chords,
            command: expandedCommand,
            line: lineNumber,
            custom: custom,
            id: custom ? meta.id : "",
            sourceKey: keyText,
            sourceCommand: commandText,
            search: (group + " " + description + " " + key + " "
                + expandedCommand).toLowerCase()
        })
    }

    return entries
}

// Hoofdfunctie: tekst -> { entries, groups, sections, error }.
function parseResult(text) {
    const lines = String(text === null || text === undefined ? "" : text)
        .split(/\r?\n/)
    const entries = []
    const groups = []
    var section = "Algemeen"
    var comments = []
    var pendingMeta = null

    var i = 0
    while (i < lines.length) {
        const line = lines[i]

        if (isBlank(line)) {
            comments = []
            i++
            continue
        }

        if (isComment(line)) {
            const meta = parseCustomMeta(line)
            if (meta !== null) {
                // Marker van een eigen binding: wel onthouden, niet tonen.
                pendingMeta = meta
                i++
                continue
            }
            if (isCustomEnd(line)) {
                pendingMeta = null
                i++
                continue
            }

            const title = sectionTitle(line)
            if (title.length > 0) {
                section = title
                comments = []
                pendingMeta = null
            } else {
                comments.push(commentText(line))
            }
            i++
            continue
        }

        if (isIndented(line)) {
            // Commando zonder voorafgaande hotkey: negeren, maar wel de
            // commentbuffer leegmaken zodat die niet aan de volgende hotkey
            // wordt geplakt.
            comments = []
            i++
            continue
        }

        // Hotkey, inclusief \ -continuties.
        var hotkey = String(line).trim()
        while (hotkey.charAt(hotkey.length - 1) === "\\"
                && i + 1 < lines.length) {
            hotkey = hotkey.substring(0, hotkey.length - 1).trim()
                + " " + String(lines[i + 1]).trim()
            i++
        }

        const commandInfo = readCommands(lines, i + 1)
        const description = comments.join(" ")
        const meta = pendingMeta
        comments = []
        pendingMeta = null

        if (commandInfo.commands.length > 0) {
            const commandText = commandInfo.commands.join("\n")
            const expanded = expandEntry(hotkey, commandText, section,
                description, i + 1, meta)
            for (var e = 0; e < expanded.length; e++)
                entries.push(expanded[e])
        }

        i = commandInfo.next
    }

    for (var g = 0; g < entries.length; g++) {
        if (groups.indexOf(entries[g].group) < 0)
            groups.push(entries[g].group)
    }

    return {
        entries: entries,
        groups: groups,
        sections: groups,
        error: ""
    }
}

function parse(text) {
    return parseResult(text).entries
}

// Filtert op zoektekst en groep. Een lege groep betekent "alle groepen".
function filter(entries, query, group) {
    const needle = String(query === null || query === undefined
        ? "" : query).trim().toLowerCase()
    const wanted = String(group === null || group === undefined
        ? "" : group)
    const result = []

    for (var i = 0; i < entries.length; i++) {
        const entry = entries[i]
        if (wanted.length > 0 && entry.group !== wanted)
            continue
        if (needle.length > 0 && entry.search.indexOf(needle) < 0)
            continue
        result.push(entry)
    }

    return result
}

// Groepeert een gefilterde lijst in de vorm die de UI tekent.
function groupEntries(entries) {
    const result = []
    var currentName = ""
    var currentEntries = []

    for (var i = 0; i < entries.length; i++) {
        const entry = entries[i]
        if (entry.group !== currentName) {
            if (currentEntries.length > 0)
                result.push({ name: currentName, entries: currentEntries })
            currentName = entry.group
            currentEntries = []
        }
        currentEntries.push(entry)
    }

    if (currentEntries.length > 0)
        result.push({ name: currentName, entries: currentEntries })

    return result
}
