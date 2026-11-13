//@ pragma UseQApplication
// shell.qml — root van de Quickshell-desktop (fase 9).
//
// Starten: qs -p /home/simon/projecten/quickshell
//
// Eén bar per scherm met live workspaces (Bspwm-service), layoutindicator,
// venstertitel, weer (Weather-service), snapper, updates (Updates-service),
// notificatiebel (NotificationDaemon), systemtray (SystemTray-service) en klok.
// De BSPWM-status komt uit `bspc subscribe report`; het weer uit Open-Meteo met
// een lokale cache; updates uit `apt list --upgradable` en
// `flatpak remote-ls --updates`; notificaties lopen via de D-Bus-naam
// org.freedesktop.Notifications.
//
// UseQApplication is nodig voor de tray-menu's: Quickshell tekent die met
// QtWidgets' QMenu (item.display()). Zonder de pragma start Quickshell als
// QGuiApplication en weigert hij platformmenu's te openen.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "src/components"
import "src/services"
import "src/windows"

ShellRoot {
    id: root

    // Met IPC te schakelen (qs ipc call bar toggle).
    property bool barVisible: true

    Variants {
        id: barVariants
        model: Quickshell.screens

        delegate: Component {
            Bar {
                required property ShellScreen modelData
                screen: modelData
                shown: root.barVisible
                onSettingsRequested: settingsWindow.toggleWindow()
                onShortcutsRequested: shortcutsWindow.toggleWindow()
                onWallpaperRequested: wallpaperWindow.toggleWindow()
                onSnapperCreateRequested: snapperCreateWindow.openWindow()
            }
        }
    }

    // Instellingenvenster (FloatingWindow, één instantie voor alle schermen).
    SettingsWindow {
        id: settingsWindow
    }

    // Sneltoetsenoverzicht (FloatingWindow, één instantie voor alle schermen).
    ShortcutsWindow {
        id: shortcutsWindow
    }

    // Wallpaperbeheer: kiezen, previewen, toevoegen en verwijderen
    // (FloatingWindow, één instantie voor alle schermen).
    WallpaperWindow {
        id: wallpaperWindow
    }

    // Nieuwe snapper-momentopname met een beschrijving
    // (FloatingWindow, één instantie voor alle schermen).
    SnapperCreateWindow {
        id: snapperCreateWindow
    }

    IpcHandler {
        target: "bar"

        // Herlaadt de QML zonder het proces te herstarten.
        function reload(): void {
            Quickshell.reload(false)
        }

        // Verbergt of toont de bar op alle schermen.
        function toggle(): void {
            root.barVisible = !root.barVisible
        }
    }

    // BSPWM-instellingen: qs ipc call settings open | close | toggle | status
    IpcHandler {
        target: "settings"

        function open(): void {
            settingsWindow.openWindow()
        }

        function close(): void {
            settingsWindow.closeWindow()
        }

        function toggle(): void {
            settingsWindow.toggleWindow()
        }

        function status(): string {
            const base = JSON.parse(BspwmSettings.status())
            base.visible = settingsWindow.visible
            return JSON.stringify(base)
        }

        // Handig voor scripts en de acceptatietest; de GUI gebruikt de
        // dezelfde service rechtstreeks.
        function reset(): void {
            BspwmSettings.reset()
        }

        function setGap(value: int): void {
            BspwmSettings.setWindowGap(value)
        }

        function setBorder(value: int): void {
            BspwmSettings.setBorderWidth(value)
        }

        function setColor(key: string, value: string): bool {
            return BspwmSettings.setColor(key, value)
        }

        // Schaalgrootte in procenten (80–150), bijvoorbeeld 125.
        function setScale(percent: int): void {
            BspwmSettings.setUiScale(percent / 100)
        }

        // Dekking van de bar in procenten (30–100), bijvoorbeeld 85.
        function setBarOpacity(percent: int): void {
            BspwmSettings.setBarOpacity(percent / 100)
        }

        function save(): void {
            BspwmSettings.saveNow()
        }
    }

    // Sneltoetsen: qs ipc call shortcuts open | close | toggle | status | list
    // Eigen bindingen: qs ipc call shortcuts add '<toetsen>' '<omschrijving>' '<commando>' ['groep']
    // Verwijderen:     qs ipc call shortcuts remove <id>
    IpcHandler {
        target: "shortcuts"

        function open(): void {
            shortcutsWindow.openWindow()
        }

        function close(): void {
            shortcutsWindow.closeWindow()
        }

        function toggle(): void {
            shortcutsWindow.toggleWindow()
        }

        function status(): string {
            var customCount = 0
            var seen = {}
            for (var i = 0; i < shortcutsWindow.entries.length; i++) {
                const entry = shortcutsWindow.entries[i]
                if (entry.custom && !seen[entry.id]) {
                    seen[entry.id] = true
                    customCount++
                }
            }
            return JSON.stringify({
                path: shortcutsWindow.sxhkdrcPath,
                visible: shortcutsWindow.visible,
                count: shortcutsWindow.entries.length,
                customCount: customCount,
                groups: shortcutsWindow.groups,
                matches: shortcutsWindow.matchCount,
                search: shortcutsWindow.searchText,
                activeGroup: shortcutsWindow.activeGroup,
                error: shortcutsWindow.parseError
            })
        }

        // Volledige geparseerde lijst; handig voor de acceptatietest.
        function list(): string {
            return JSON.stringify(shortcutsWindow.entries)
        }

        // Voegt een eigen binding toe. Geeft JSON terug met ok/id/error;
        // bijwerken gebeurt met update(id, …).
        function add(keys: string, description: string, command: string,
                group: string): string {
            return JSON.stringify(shortcutsWindow.addShortcut(keys,
                description, command, group))
        }

        function update(id: string, keys: string, description: string,
                command: string, group: string): string {
            return JSON.stringify(shortcutsWindow.saveShortcut({
                id: id,
                keys: keys,
                description: description,
                command: command,
                group: group
            }))
        }

        function remove(id: string): string {
            const ok = shortcutsWindow.removeShortcut(id)
            return JSON.stringify({
                ok: ok,
                id: id,
                error: ok ? "" : "Sneltoets niet gevonden"
            })
        }

        function reload(): void {
            shortcutsWindow.reloadFromDisk()
        }
    }

    // Weer: qs ipc call weather status | refresh | open | close | toggle
    IpcHandler {
        target: "weather"

        function refresh(): void {
            Weather.refresh()
        }

        // Openen/sluiten van de weerpopup (handig voor sneltoetsen en tests).
        function open(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].openWeatherPopup()
        }

        function close(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].closeWeatherPopup()
        }

        function toggle(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].toggleWeatherPopup()
        }

        function status(): string {
            return JSON.stringify({
                location: Weather.location,
                loading: Weather.loading,
                error: Weather.lastError,
                cachePath: Weather.cachePath,
                lastUpdated: Weather.lastUpdated
                    ? Weather.lastUpdated.toISOString() : null,
                updatedLabel: Weather.updatedLabel(),
                current: Weather.current,
                daily: Weather.daily
            })
        }
    }

    // Meldingen: qs ipc call notifications status | clear | dnd <bool> |
    //           getDnd | open | close | toggle
    IpcHandler {
        target: "notifications"

        function status(): string {
            return Notifications.status()
        }

        function clear(): void {
            Notifications.clear()
        }

        function dnd(value: bool): bool {
            Notifications.setDnd(value)
            return Notifications.dnd
        }

        function getDnd(): bool {
            return Notifications.dnd
        }

        function toggleDnd(): bool {
            Notifications.toggleDnd()
            return Notifications.dnd
        }

        function open(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].openNotificationCenter()
        }

        function close(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].closeNotificationCenter()
        }

        function toggle(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].toggleNotificationCenter()
        }
    }

    // Sessiemenu: qs ipc call power open | close | toggle | status
    // Acties:    qs ipc call power lock | logout | sleep | reboot | shutdown
    IpcHandler {
        target: "power"

        function open(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].openPowerMenu()
        }

        function close(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].closePowerMenu()
        }

        function toggle(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].togglePowerMenu()
        }

        function status(): string {
            return JSON.stringify({
                visible: barVariants.instances.length > 0
                    ? barVariants.instances[0].powerMenuVisible : false,
                lockScript: Power.lockScript,
                lastAction: Power.lastAction
            })
        }

        function lock(): void {
            Power.lock()
        }

        function logout(): void {
            Power.logout()
        }

        function sleep(): void {
            Power.sleep()
        }

        function reboot(): void {
            Power.reboot()
        }

        function shutdown(): void {
            Power.shutdown()
        }
    }

    // Snapper: qs ipc call snapper open | close | toggle | status | list |
    //          refresh | config <naam> | create [beschrijving] | remove <nr> |
    //          cleanup <max> | rollback <nr> | editor
    IpcHandler {
        target: "snapper"

        function open(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].openSnapperPopup()
        }

        function close(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].closeSnapperPopup()
        }

        function toggle(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].toggleSnapperPopup()
        }

        function status(): string {
            const base = Snapper.status()
            base.visible = barVariants.instances.length > 0
                ? barVariants.instances[0].snapperPopupVisible : false
            return JSON.stringify(base)
        }

        function list(): string {
            return JSON.stringify(Snapper.snapshots)
        }

        function refresh(): void {
            Snapper.refresh()
        }

        function config(name: string): bool {
            return Snapper.selectConfig(name)
        }

        // Opent het invoervenster voor een nieuwe momentopname.
        function editor(): void {
            snapperCreateWindow.openWindow()
        }

        // Direct aanmaken zonder dialoog; handig voor scripts en tests.
        function create(description: string): bool {
            return Snapper.create(description)
        }

        function remove(number: int): bool {
            return Snapper.remove(number)
        }

        // Oudste momentopnamen verwijderen tot er maximaal `max` overblijven.
        function cleanup(max: int): bool {
            return Snapper.cleanup(max)
        }

        // Bereid een rollback voor; actief na een herstart.
        function rollback(number: int): bool {
            return Snapper.rollback(number)
        }
    }

    // Updates: qs ipc call updates open | close | toggle | status | refresh |
    //          update
    IpcHandler {
        target: "updates"

        function open(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].openUpdatesPopup()
        }

        function close(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].closeUpdatesPopup()
        }

        function toggle(): void {
            if (barVariants.instances.length > 0)
                barVariants.instances[0].toggleUpdatesPopup()
        }

        function status(): string {
            const base = Updates.status()
            base.visible = barVariants.instances.length > 0
                ? barVariants.instances[0].updatesPopupVisible : false
            return JSON.stringify(base)
        }

        function refresh(): void {
            Updates.refresh()
        }

        // Werkt eerst APT en daarna Flatpak bij (met bevestiging in de GUI).
        function update(): bool {
            return Updates.updateAll()
        }
    }

    // Wallpapers: qs ipc call wallpaper open | close | toggle | status | list |
    //           refresh | next | set <pad> | add <pad> | remove <pad>
    IpcHandler {
        target: "wallpaper"

        function open(): void {
            wallpaperWindow.openWindow()
        }

        function close(): void {
            wallpaperWindow.closeWindow()
        }

        function toggle(): void {
            wallpaperWindow.toggleWindow()
        }

        function status(): string {
            return JSON.stringify(Wallpaper.status())
        }

        function list(): string {
            return JSON.stringify(Wallpaper.items)
        }

        function refresh(): void {
            Wallpaper.refresh()
        }

        function next(): bool {
            return Wallpaper.next()
        }

        function set(path: string): bool {
            return Wallpaper.apply(path)
        }

        function add(path: string): string {
            return Wallpaper.add(path)
        }

        function remove(path: string): bool {
            return Wallpaper.remove(path)
        }
    }

    // Diagnostiek: qs ipc call bspwm status
    IpcHandler {
        target: "bspwm"

        function status(): string {
            return JSON.stringify({
                available: Bspwm.available,
                error: Bspwm.lastError,
                focusedMonitor: Bspwm.focusedMonitor,
                focusedDesktop: Bspwm.focusedDesktop,
                layout: Bspwm.layout,
                activeNodeState: Bspwm.activeNodeState,
                activeNodeFlags: Bspwm.activeNodeFlags,
                desktops: Bspwm.desktops
            })
        }
    }

    // Diagnostiek: qs ipc call tray status
    IpcHandler {
        target: "tray"

        function status(): string {
            const values = SystemTray.items.values
            const items = []
            for (let i = 0; i < values.length; i++) {
                const item = values[i]
                items.push({
                    id: item.id,
                    title: item.title,
                    icon: item.icon,
                    tooltipTitle: item.tooltipTitle,
                    tooltipDescription: item.tooltipDescription,
                    hasMenu: item.hasMenu,
                    onlyMenu: item.onlyMenu,
                    status: item.status,
                    category: item.category
                })
            }
            return JSON.stringify({
                count: values.length,
                items: items
            })
        }
    }
}
