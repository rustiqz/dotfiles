pragma Singleton
import Quickshell

// Pokédex flavour for the launcher: freedesktop categories → Pokémon
// types. The mapping is playful but stable, so an app's "type" badge is
// a real, glanceable signal (Steel = dev tool, Flying = network, ...).
//
// Colours are the canonical type colours, deliberately NOT from the
// theme: they're the one place an outside palette is the point — a Fire
// badge should be fire-orange under every theme, the same way a terminal
// keeps its ANSI hues.
Singleton {
    readonly property var types: ({
        steel:    { name: "Steel",    color: "#B7B7CE" },   // development
        fighting: { name: "Fighting", color: "#C22E28" },   // terminals / system
        flying:   { name: "Flying",   color: "#A98FF3" },   // network, browsers, chat
        psychic:  { name: "Psychic",  color: "#F95587" },   // audio / video
        fairy:    { name: "Fairy",    color: "#D685AD" },   // graphics
        grass:    { name: "Grass",    color: "#7AC74C" },   // office
        fire:     { name: "Fire",     color: "#EE8130" },   // games
        electric: { name: "Electric", color: "#F7D02C" },   // utilities
        water:    { name: "Water",    color: "#6390F0" },   // education / science
        dark:     { name: "Dark",     color: "#705746" },   // security
        ground:   { name: "Ground",   color: "#E2BF65" },   // files
        normal:   { name: "Normal",   color: "#A8A77A" },   // settings / anything else
    })

    // First match wins, in this order — so "Development;TerminalEmulator"
    // is Steel/Fighting, never the other way round.
    readonly property var rules: [
        ["Development", "steel"], ["IDE", "steel"], ["Debugger", "steel"],
        ["TerminalEmulator", "fighting"], ["System", "fighting"], ["Monitor", "fighting"],
        ["WebBrowser", "flying"], ["Network", "flying"], ["Email", "flying"], ["Chat", "flying"],
        ["InstantMessaging", "flying"],
        ["Audio", "psychic"], ["Video", "psychic"], ["AudioVideo", "psychic"], ["Music", "psychic"],
        ["Player", "psychic"],
        ["Graphics", "fairy"], ["Photography", "fairy"], ["2DGraphics", "fairy"], ["3DGraphics", "fairy"],
        ["Office", "grass"], ["WordProcessor", "grass"], ["Spreadsheet", "grass"], ["Presentation", "grass"],
        ["Game", "fire"],
        ["Utility", "electric"], ["Accessories", "electric"], ["TextEditor", "electric"],
        ["Education", "water"], ["Science", "water"], ["Math", "water"],
        ["Security", "dark"],
        ["FileManager", "ground"], ["FileTools", "ground"], ["Archiving", "ground"],
        ["Settings", "normal"], ["DesktopSettings", "normal"], ["HardwareSettings", "normal"],
    ]

    // categories: a ";"-separated string or a list (DesktopEntry exposes
    // either depending on version). Returns up to two type objects.
    function typesFor(categories) {
        const cats = Array.isArray(categories) ? categories
                   : String(categories || "").split(";").filter(Boolean)
        const out = []
        for (const [cat, t] of rules) {
            if (cats.includes(cat) && !out.includes(t)) out.push(t)
            if (out.length === 2) break
        }
        if (out.length === 0) out.push("normal")
        return out.map(t => types[t])
    }

    // Dex number, zero-padded the way the games print it: No. 007.
    function no(n) { return "No. " + String(n).padStart(3, "0") }
}
