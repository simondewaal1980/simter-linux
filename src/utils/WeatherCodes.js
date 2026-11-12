.pragma library

// WeatherCodes.js — WMO-weercodes (Open-Meteo) → Nederlandse tekst + icoon.
//
// Open-Meteo levert de WMO 4677-codes in `weather_code`. De indeling hieronder
// volgt de officiële groepen (0–3 helder/bewolkt, 45–48 mist, 51–57 motregen,
// 61–67 regen, 71–77 sneeuw, 80–82 buien, 85–86 sneeuwbuien, 95–99 onweer).
// De iconen zijn Font Awesome 6 Free Solid-codepoints (zie Theme.iconFamily).

function describe(code) {
    var c = Number(code)
    if (isNaN(c))
        return { text: "Onbekend", icon: "\uf059" }

    switch (c) {
    case 0:
        return { text: "Onbewolkt", icon: "\uf185" }          // sun
    case 1:
        return { text: "Overwegend helder", icon: "\uf185" }  // sun
    case 2:
        return { text: "Gedeeltelijk bewolkt", icon: "\uf6c4" } // cloud-sun
    case 3:
        return { text: "Bewolkt", icon: "\uf0c2" }            // cloud

    case 45:
        return { text: "Mist", icon: "\uf75f" }               // smog
    case 48:
        return { text: "Aanvriezende mist", icon: "\uf75f" }  // smog

    case 51:
        return { text: "Lichte motregen", icon: "\uf73d" }    // cloud-rain
    case 53:
        return { text: "Motregen", icon: "\uf73d" }           // cloud-rain
    case 55:
        return { text: "Zware motregen", icon: "\uf740" }     // cloud-showers-heavy
    case 56:
    case 57:
        return { text: "Aanvriezende motregen", icon: "\uf2dc" } // snowflake

    case 61:
        return { text: "Lichte regen", icon: "\uf73d" }       // cloud-rain
    case 63:
        return { text: "Regen", icon: "\uf73d" }              // cloud-rain
    case 65:
        return { text: "Zware regen", icon: "\uf740" }        // cloud-showers-heavy
    case 66:
    case 67:
        return { text: "Aanvriezende regen", icon: "\uf2dc" } // snowflake

    case 71:
        return { text: "Lichte sneeuwval", icon: "\uf2dc" }   // snowflake
    case 73:
        return { text: "Sneeuwval", icon: "\uf2dc" }          // snowflake
    case 75:
        return { text: "Zware sneeuwval", icon: "\uf2dc" }    // snowflake
    case 77:
        return { text: "Sneeuwkorrels", icon: "\uf2dc" }      // snowflake

    case 80:
        return { text: "Lichte buien", icon: "\uf73d" }       // cloud-rain
    case 81:
        return { text: "Buien", icon: "\uf73d" }              // cloud-rain
    case 82:
        return { text: "Zware buien", icon: "\uf740" }        // cloud-showers-heavy
    case 85:
        return { text: "Lichte sneeuwbuien", icon: "\uf2dc" } // snowflake
    case 86:
        return { text: "Zware sneeuwbuien", icon: "\uf2dc" }  // snowflake

    case 95:
        return { text: "Onweer", icon: "\uf0e7" }             // bolt
    case 96:
    case 99:
        return { text: "Onweer met hagel", icon: "\uf0e7" }   // bolt

    default:
        return { text: "Onbekend", icon: "\uf059" }           // circle-question
    }
}

function text(code) {
    return describe(code).text
}

function icon(code) {
    return describe(code).icon
}
