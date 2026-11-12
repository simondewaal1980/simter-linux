pragma Singleton

// Weather.qml — actueel weer en verwachting voor Eindhoven (Open-Meteo).
//
// De service haalt één keer per tien minuten een forecast op met curl. Bij een
// fout (geen netwerk, time-out, onleesbare JSON) blijft de laatst bekende
// waarde staan en wordt het na 60 seconden opnieuw geprobeerd. Elke geslaagde
// respons wordt in de Quickshell-cache bewaard, zodat de bar na een herstart
// en zonder netwerk meteen iets kan tonen.
//
// De widget/popup leest alleen de genormaliseerde velden hieronder; de ruwe
// Open-Meteo-respons verlaat deze service nooit.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string location: "Eindhoven"

    readonly property string defaultEndpoint: "https://api.open-meteo.com/v1/forecast?latitude=51.4416&longitude=5.4697&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Europe%2FAmsterdam&forecast_days=4&temperature_unit=celsius&wind_speed_unit=kmh"

    // Alleen voor gecontroleerd testen van de foutafhandeling: een andere
    // URL meegeven (bijvoorbeeld een onbereikbaar adres) laat de cache- en
    // foutpad-tests reproducibel verlopen.
    readonly property string endpoint: {
        const override = Quickshell.env("WEATHER_ENDPOINT")
        if (override && override.length > 0)
            return override
        return root.defaultEndpoint
    }

    readonly property string cachePath: Quickshell.cachePath("weather-eindhoven.json")

    readonly property int refreshInterval: 10 * 60 * 1000
    readonly property int retryInterval: 60 * 1000

    // --- Genormaliseerde status -------------------------------------------

    // { temperature, apparentTemperature, humidity, precipitation,
    //   weatherCode, windSpeed, time }
    property var current: null

    // [{ date, weatherCode, min, max, precipitationProbability }, ...]
    // index 0 = vandaag, daarna de drie volgende dagen.
    property var daily: []

    property bool loading: false
    property string lastError: ""
    property var lastUpdated: null

    readonly property bool hasData: root.current !== null

    readonly property var today: root.daily.length > 0 ? root.daily[0] : null

    // --- Respons verwerken ------------------------------------------------

    function applyResponse(response, fetchedAt) {
        const c = response.current
        root.current = {
            temperature: c.temperature_2m,
            apparentTemperature: c.apparent_temperature,
            humidity: c.relative_humidity_2m,
            precipitation: c.precipitation,
            weatherCode: c.weather_code,
            windSpeed: c.wind_speed_10m,
            time: c.time
        }

        const d = response.daily || {}
        const times = d.time || []
        const days = []
        for (var i = 0; i < times.length; i++) {
            days.push({
                date: times[i],
                weatherCode: d.weather_code ? d.weather_code[i] : null,
                min: d.temperature_2m_min ? d.temperature_2m_min[i] : null,
                max: d.temperature_2m_max ? d.temperature_2m_max[i] : null,
                precipitationProbability: d.precipitation_probability_max
                    ? d.precipitation_probability_max[i] : null
            })
        }
        root.daily = days
        root.lastUpdated = new Date(fetchedAt)
        root.lastError = ""
    }

    function handleResponse(text) {
        var response = null
        try {
            response = JSON.parse(text)
        } catch (error) {
            root.markFailure("Onleesbaar weerbericht")
            return
        }

        if (!response || !response.current || !response.daily) {
            root.markFailure("Onvolledig weerbericht")
            return
        }

        const fetchedAt = Date.now()
        root.applyResponse(response, fetchedAt)
        root.writeCache(response, fetchedAt)
        retryTimer.stop()
        // Na een geslaagde (her)poging weer tien minuten wachten.
        refreshTimer.restart()
    }

    function markFailure(message) {
        root.loading = false
        root.lastError = message
        if (!retryTimer.running)
            retryTimer.start()
    }

    // --- Cache ------------------------------------------------------------

    function loadCache() {
        // Een vers opgehaalde respons is altijd nieuwer dan de cache.
        if (root.lastUpdated !== null)
            return

        const text = cacheReader.text()
        if (!text || text.length === 0)
            return

        var cached = null
        try {
            cached = JSON.parse(text)
        } catch (error) {
            return
        }
        if (!cached)
            return

        // Wrapper-formaat { fetchedAt, response }; een kale respons wordt ook
        // geaccepteerd (bijvoorbeeld een handmatig geplaatst cachebestand).
        const response = cached.response ? cached.response : cached
        const fetchedAt = typeof cached.fetchedAt === "number"
            ? cached.fetchedAt : Date.now()

        if (!response || !response.current || !response.daily)
            return

        root.applyResponse(response, fetchedAt)
    }

    function writeCache(response, fetchedAt) {
        cacheWriter.setText(JSON.stringify({
            fetchedAt: fetchedAt,
            response: response
        }))
    }

    // --- Ophalen ----------------------------------------------------------

    function refresh() {
        if (fetchProcess.running)
            return
        root.loading = true
        fetchProcess.running = true
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

    // --- Processen --------------------------------------------------------

    Process {
        id: fetchProcess
        command: ["curl", "-fsS", "--max-time", "10", root.endpoint]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleResponse(text)
        }

        stderr: StdioCollector {
            id: errorCollector
            waitForEnd: true
        }

        onExited: (exitCode) => {
            root.loading = false
            if (exitCode !== 0) {
                const detail = errorCollector.text.trim()
                // curl's melding is Engels en vaak lang; houd de status kort
                // en bewaar alleen de eerste regel als technische toelichting.
                root.markFailure(detail.length > 0
                    ? "Geen weerdata (" + detail.split("\n")[0] + ")"
                    : "Geen weerdata (curl " + exitCode + ")")
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Timer {
        id: retryTimer
        interval: root.retryInterval
        repeat: false
        running: false
        onTriggered: root.refresh()
    }

    FileView {
        id: cacheReader
        path: root.cachePath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: cacheWriter
        path: root.cachePath
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        root.loadCache()
        root.refresh()
    }
}
