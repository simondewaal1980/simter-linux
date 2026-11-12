pragma Singleton

// NotificationDaemon.qml — de enige notificatiedaemon van de sessie.
//
// Quickshells NotificationServer neemt `org.freedesktop.Notifications` over.
// Deze service bewaart de geschiedenis (max. 50), houdt bij welke meldingen
// ongelezen zijn, regelt "niet storen" (DND) en bepaalt welke meldingen als
// popup verschijnen (max. 4). De popup- en centrumcomponenten lezen alleen de
// eigenschappen en functies hieronder.
//
// Meldingen blijven in leven zolang ze getrackt zijn (`tracked = true`). Dat
// is nodig voor de geschiedenis én voor `keepOnReload`: na een reload biedt
// Quickshell de getrackte meldingen opnieuw aan met `lastGeneration = true`.
// Die komen dan alleen in de geschiedenis, zonder popup of badge.
//
// Time-out: kritieke meldingen verdwijnen nooit automatisch, `expireTimeout`
// 0 betekent "nooit" (volgens de Desktop Notifications-spec), een positieve
// waarde is het aantal milliseconden en -1 laat de standaardkeuze aan ons
// (laag 4 s, normaal 8 s). Popups pauzeren zolang de muis erboven hangt.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property int maxHistory: 50
    readonly property int maxPopups: 4

    // --- Status -----------------------------------------------------------

    property bool dnd: false

    // [{ notification: Notification, receivedAt: epoch-ms }], nieuwste eerst.
    property var history: []

    // Zichtbare popups (Notification-objecten), nieuwste eerst.
    property var popups: []

    // Id's van meldingen die nog niet in het centrum zijn bekeken.
    property var unreadIds: []

    // Gevuld als een andere daemon de D-Bus-naam bezit.
    property string dbusConflict: ""

    readonly property int historyCount: root.history.length
    readonly property int popupCount: root.popups.length
    readonly property int unreadCount: root.unreadIds.length

    // --- Server -----------------------------------------------------------

    NotificationServer {
        id: server

        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false
        keepOnReload: true

        onNotification: (notification) => root.handleNotification(notification)
    }

    // --- Inkomende meldingen ---------------------------------------------

    function handleNotification(notification) {
        if (!notification)
            return

        // Zonder deze vlag verwijdert de server de melding direct na het
        // signaal; de popup en geschiedenis hebben het object nog nodig.
        notification.tracked = true

        // Na een reload opnieuw aangeboden: alleen de geschiedenis herstellen.
        if (notification.lastGeneration) {
            root.addToHistory(notification, false)
            return
        }

        // Transient meldingen horen niet in de geschiedenis of badge; ze
        // bestaan alleen als popup zolang ze relevant zijn.
        if (notification.transient) {
            if (root.dnd)
                notification.tracked = false
            else
                root.showPopup(notification)
            return
        }

        root.addToHistory(notification, true)
        if (!root.dnd)
            root.showPopup(notification)
    }

    function addToHistory(notification, markUnread) {
        // Een melding kan opnieuw worden aangeboden bij vervanging
        // (replaces_id) of na een reload. Houd dan één record per id aan
        // in plaats van een dubbele geschiedenisregel.
        var existingIndex = -1
        for (var i = 0; i < root.history.length; i++) {
            const record = root.history[i]
            if (record.notification === notification
                    || record.notification.id === notification.id) {
                existingIndex = i
                break
            }
        }

        if (existingIndex === -1
                || root.history[existingIndex].notification !== notification) {
            notification.closed.connect(function(reason) {
                root.forgetNotification(notification)
            })
        }

        var kept = []
        for (var j = 0; j < root.history.length; j++) {
            if (j !== existingIndex)
                kept.push(root.history[j])
        }

        root.history = [{
            notification: notification,
            receivedAt: Date.now()
        }].concat(kept)

        if (markUnread && root.unreadIds.indexOf(notification.id) === -1)
            root.unreadIds = root.unreadIds.concat([notification.id])

        root.trimHistory()
    }

    function trimHistory() {
        if (root.history.length <= root.maxHistory)
            return

        const dropped = root.history.slice(root.maxHistory)
        root.history = root.history.slice(0, root.maxHistory)

        for (var i = 0; i < dropped.length; i++) {
            const notification = dropped[i].notification
            root.removeUnreadId(notification.id)
            // tracked = false is gelijk aan dismiss(): de server ruimt de
            // melding op en de client krijgt een close-signaal.
            notification.tracked = false
        }
    }

    function isInHistory(notification) {
        for (var i = 0; i < root.history.length; i++) {
            if (root.history[i].notification === notification)
                return true
        }
        return false
    }

    function forgetNotification(notification) {
        var keptHistory = []
        for (var i = 0; i < root.history.length; i++) {
            if (root.history[i].notification !== notification)
                keptHistory.push(root.history[i])
        }
        if (keptHistory.length !== root.history.length)
            root.history = keptHistory

        var keptPopups = []
        for (var j = 0; j < root.popups.length; j++) {
            if (root.popups[j] !== notification)
                keptPopups.push(root.popups[j])
        }
        if (keptPopups.length !== root.popups.length)
            root.popups = keptPopups

        root.removeUnreadId(notification.id)
    }

    function removeUnreadId(id) {
        var kept = []
        for (var i = 0; i < root.unreadIds.length; i++) {
            if (root.unreadIds[i] !== id)
                kept.push(root.unreadIds[i])
        }
        if (kept.length !== root.unreadIds.length)
            root.unreadIds = kept
    }

    // --- Popups -----------------------------------------------------------

    function showPopup(notification) {
        for (var i = 0; i < root.popups.length; i++) {
            if (root.popups[i] === notification)
                return
        }

        // Nieuwste bovenaan; oudere popups vallen weg maar blijven in de
        // geschiedenis staan.
        var next = [notification]
        for (var j = 0; j < root.popups.length && next.length < root.maxPopups; j++)
            next.push(root.popups[j])
        root.popups = next
    }

    // Sluit alleen de popup; een melding in de geschiedenis blijft bestaan.
    function expirePopup(notification) {
        var next = []
        var found = false
        for (var i = 0; i < root.popups.length; i++) {
            if (root.popups[i] === notification)
                found = true
            else
                next.push(root.popups[i])
        }
        if (!found)
            return

        root.popups = next

        // Een transient melding staat niet in de geschiedenis en mag nu weg.
        if (!root.isInHistory(notification))
            notification.tracked = false
    }

    // --- Geschiedenis -----------------------------------------------------

    // Sluit een melding definitief (ook uit de geschiedenis).
    function dismissNotification(notification) {
        root.forgetNotification(notification)
        try {
            notification.dismiss()
        } catch (error) {
            // De client kan de melding intussen al hebben gesloten.
        }
    }

    function clear() {
        const records = root.history.slice()
        root.history = []
        root.popups = []
        root.unreadIds = []

        for (var i = 0; i < records.length; i++) {
            try {
                records[i].notification.tracked = false
            } catch (error) {
                // Al verdwenen.
            }
        }
    }

    function markAllRead() {
        root.unreadIds = []
    }

    // --- DND --------------------------------------------------------------

    function setDnd(value) {
        const next = value === true
        if (root.dnd === next)
            return

        root.dnd = next

        // DND aan: bestaande popups verbergen, maar wel in de geschiedenis
        // laten staan. Transiente meldingen mogen daarna echt weg.
        if (next) {
            const visible = root.popups.slice()
            root.popups = []
            for (var i = 0; i < visible.length; i++) {
                if (!root.isInHistory(visible[i]))
                    visible[i].tracked = false
            }
        }
    }

    function toggleDnd() {
        root.setDnd(!root.dnd)
    }

    // --- Weergave-helpers -------------------------------------------------

    function timeoutMs(notification) {
        if (notification.urgency === NotificationUrgency.Critical)
            return 0
        if (notification.expireTimeout === 0)
            return 0
        // Quickshell 0.3.2 levert expireTimeout in milliseconden (de
        // D-Bus-specificatie), ook al zegt de documentatie seconden.
        if (notification.expireTimeout > 0)
            return Math.round(notification.expireTimeout)
        return notification.urgency === NotificationUrgency.Low ? 4000 : 8000
    }

    function urgencyName(value) {
        if (value === NotificationUrgency.Critical)
            return "critical"
        if (value === NotificationUrgency.Low)
            return "low"
        return "normal"
    }

    function relativeTime(receivedAt, now) {
        const reference = typeof now === "number" ? now : Date.now()
        const seconds = Math.max(0, Math.round((reference - receivedAt) / 1000))
        if (seconds < 45)
            return "zojuist"
        if (seconds < 3600)
            return Math.round(seconds / 60) + " min"
        if (seconds < 86400)
            return Math.round(seconds / 3600) + " u"
        return Math.round(seconds / 86400) + " d"
    }

    // Zet een appIcon om naar een bruikbare Image-bron. Een icoonnaam die
    // niet in het thema zit levert anders een "image missing"-plaatsje op;
    // in dat geval tonen de popups liever hun eigen Font Awesome-terugval.
    function appIconSource(icon) {
        if (!icon || icon.length === 0)
            return ""
        if (icon.charAt(0) === "/" || icon.indexOf("file:") === 0)
            return icon
        if (!Quickshell.hasThemeIcon(icon))
            return ""
        return Quickshell.iconPath(icon, "")
    }

    // --- Diagnostiek ------------------------------------------------------

    function notificationSnapshot(notification) {
        const actions = []
        for (var i = 0; i < notification.actions.length; i++) {
            actions.push({
                identifier: notification.actions[i].identifier,
                text: notification.actions[i].text
            })
        }

        return {
            id: notification.id,
            appName: notification.appName,
            appIcon: notification.appIcon,
            summary: notification.summary,
            body: notification.body,
            urgency: root.urgencyName(notification.urgency),
            expireTimeout: notification.expireTimeout,
            timeoutMs: root.timeoutMs(notification),
            image: notification.image,
            actions: actions
        }
    }

    function status() {
        const visible = []
        for (var i = 0; i < root.popups.length; i++)
            visible.push(root.notificationSnapshot(root.popups[i]))

        const stored = []
        for (var j = 0; j < root.history.length; j++) {
            const record = root.history[j]
            const item = root.notificationSnapshot(record.notification)
            item.receivedAt = new Date(record.receivedAt).toISOString()
            item.receivedLabel = root.relativeTime(record.receivedAt, Date.now())
            item.unread = root.unreadIds.indexOf(record.notification.id) !== -1
            stored.push(item)
        }

        return JSON.stringify({
            dnd: root.dnd,
            conflict: root.dbusConflict,
            unread: root.unreadCount,
            popups: visible,
            history: stored
        })
    }

    function reportConflict(message) {
        root.dbusConflict = message
        console.warn("NotificationDaemon: " + message)
    }

    // --- D-Bus-conflictcontrole -------------------------------------------
    // Quickshell registreert de naam bij het aanmaken van de server. Deze
    // controle kijkt na de start wie de eigenaar is: een andere PID betekent
    // dat bijvoorbeeld lxqt-notificationd of dunst al actief is en dat
    // meldingen daar naartoe gaan.

    Process {
        id: ownerProcess

        command: ["gdbus", "call", "--session",
                  "--dest", "org.freedesktop.DBus",
                  "--object-path", "/org/freedesktop/DBus",
                  "--method", "org.freedesktop.DBus.GetConnectionUnixProcessID",
                  "org.freedesktop.Notifications"]

        stdout: StdioCollector {
            id: ownerOutput
            waitForEnd: true
        }

        stderr: StdioCollector {
            id: ownerError
            waitForEnd: true
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.reportConflict("kon org.freedesktop.Notifications niet registreren ("
                    + ownerError.text.trim() + ")")
                return
            }

            const match = /\(uint32\s+(\d+),?\)/.exec(ownerOutput.text)
            const owner = match ? Number(match[1]) : -1
            if (owner !== Quickshell.processId) {
                root.reportConflict("org.freedesktop.Notifications is eigendom van PID "
                    + owner + " (Quickshell is " + Quickshell.processId + ")")
            } else {
                root.dbusConflict = ""
            }
        }
    }

    Timer {
        id: ownerTimer
        interval: 1200
        repeat: false
        running: true
        onTriggered: {
            if (!ownerProcess.running)
                ownerProcess.running = true
        }
    }
}
