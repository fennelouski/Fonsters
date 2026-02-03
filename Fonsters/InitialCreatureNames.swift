//
//  InitialCreatureNames.swift
//  Fonsters
//
//  Premade names and generator for initial creature naming on first launch.
//  50/50 premade vs generated; generated names are 2–4 words (equal probability).
//

import Foundation

enum InitialCreatureNames {
    /// 250 premade creature names for first-launch seeding.
    static let premade: [String] = {
        let all = [
        "Bramble", "Zephyr", "Moss", "Nimbus", "Puddle", "Ember", "Pebble", "Willow", "Clover", "Rustle",
        "Flicker", "Drizzle", "Haze", "Glint", "Thistle", "Breeze", "Shade", "Spark", "Frost", "Mist",
        "Blink", "Drift", "Flutter", "Glimmer", "Hollow", "Jasper", "Kelp", "Luna", "Murk", "Nod",
        "Onyx", "Pine", "Quill", "Ripple", "Slate", "Tide", "Umber", "Vex", "Wisp", "Yarn",
        "Apex", "Bog", "Cove", "Dew", "Echo", "Fern", "Gale", "Hearth", "Ivy", "Jade",
        "Kite", "Lark", "Marsh", "Nettle", "Oak", "Pond", "Reed", "Sage", "Tarn", "Urchin",
        "Vale", "Wren", "Yarrow", "Ash", "Bolt", "Crest", "Dune", "Elm", "Fog", "Grove",
        "Haze", "Ink", "Jolt", "Knoll", "Loom", "Moth", "Nook", "Orb", "Puff", "Quartz",
        "Rune", "Stem", "Tusk", "Vine", "Wool", "Zest", "Blur", "Chime", "Dew", "Flux",
        "Grit", "Hush", "Iris", "Jewel", "Kindle", "Lilac", "Mica", "Nova", "Omen", "Prism",
        "Quest", "Rust", "Soot", "Trove", "Umbra", "Vault", "Whorl", "Zenith", "Aria", "Bloom",
        "Cipher", "Dusk", "Ether", "Flint", "Gossamer", "Haven", "Indigo", "Jasper", "Kismet", "Labyrinth",
        "Meridian", "Nectar", "Oasis", "Palisade", "Quiver", "Reverie", "Solace", "Talisman", "Utopia", "Verdant",
        "Wander", "Xylem", "Yonder", "Zephyr", "Aloe", "Beryl", "Coral", "Dahlia", "Eden", "Fjord",
        "Garnet", "Hibiscus", "Islet", "Juniper", "Kestrel", "Lotus", "Marble", "Narcissus", "Opal", "Petrel",
        "Quill", "Rhodonite", "Saffron", "Topaz", "Umber", "Violet", "Wisteria", "Xanadu", "Yam", "Zinnia",
        "Avalanche", "Blizzard", "Cascade", "Delta", "Equinox", "Freshet", "Glacier", "Hurricane", "Iceberg", "Jetstream",
        "Kelp", "Lagoon", "Monsoon", "Nebula", "Ozone", "Prairie", "Quagmire", "Rapids", "Savanna", "Tundra",
        "Updraft", "Vortex", "Waterfall", "Xeric", "Yielding", "Zonal", "Amber", "Basalt", "Cinnabar", "Dolomite",
        "Emerald", "Feldspar", "Granite", "Hematite", "Igneous", "Jadeite", "Kimberlite", "Lapis", "Malachite", "Obsidian",
        "Pyrite", "Quartzite", "Rhyolite", "Serpentine", "Talc", "Unakite", "Vesuvian", "Wavellite", "Xenolith", "Zeolite",
        "Aurora", "Boreal", "Celestial", "Dawn", "Eclipse", "Full Moon", "Galaxy", "Horizon", "Iridescent", "Jupiter",
        "Kaleidoscope", "Lunar", "Meteor", "Nebula", "Orbit", "Pleiades", "Quasar", "Radiant", "Stellar", "Twilight",
        "Umbra", "Venus", "Waning", "X-ray", "Yonder", "Zenith", "Alpenglow", "Blaze", "Candle", "Dimmer",
        "Ember", "Flame", "Glow", "Hearth", "Inferno", "Jack-o-Lantern", "Kindle", "Lamp", "Match", "Nova",
        "Oven", "Pilot", "Quench", "Radiator", "Sun", "Torch", "Ultraviolet", "Volcano", "Warmth", "Xenon",
        "Yule", "Zinc", "Acorn", "Bark", "Branch", "Cone", "Dew", "Evergreen", "Frond", "Grain",
        "Husk", "Ivy", "Jungle", "Kernel", "Leaf", "Moss", "Needle", "Oak", "Pollen", "Root",
        "Sap", "Thorn", "Underbrush", "Vine", "Wood", "Xylem", "Yew", "Zinnia", "Bubble", "Current",
        "Droplet", "Eddy", "Foam", "Geyser", "Harbor", "Inlet", "Jetty", "Krill", "Liquid", "Marsh",
        "Nautical", "Ocean", "Pool", "Quay", "Reef", "Surf", "Tide", "Undertow", "Vessel", "Wake",
        "Wave", "Wharf", "Xebec", "Yacht", "Zephyr",
        ]
        return Array(all.prefix(250))
    }()

    /// Returns one name for an initial creature: 50% from premade (consuming from shuffled list), 50% generated.
    /// If premade is chosen but list is exhausted, falls back to generated.
    static func nextName(premadeShuffle: inout [String], premadeIndex: inout Int) -> String {
        let usePremade = Bool.random()
        if usePremade, premadeIndex < premadeShuffle.count {
            let name = premadeShuffle[premadeIndex]
            premadeIndex += 1
            return name
        }
        return CreatureNameGenerator.generate()
    }

    /// Shuffled premade list for use with nextName. Call once before the seed loop.
    static func shuffledPremade() -> [String] {
        premade.shuffled()
    }
}

enum CreatureNameGenerator {
    private static let adjectives: [String] = [
        "Swift", "Blue", "Misty", "Tiny", "Bright", "Dark", "Silent", "Golden", "Frosty", "Wild",
        "Calm", "Bold", "Shady", "Fuzzy", "Smooth", "Rusty", "Dusty", "Mellow", "Warm", "Cold",
        "Quick", "Lazy", "Happy", "Sleepy", "Cozy", "Fancy", "Plain", "Strange", "Ancient", "Young",
        "Lucky", "Clever", "Gentle", "Fierce", "Loud", "Quiet", "Proud", "Shy", "Brave", "Kind",
        "Wise", "Sly", "Brisk", "Damp", "Dry", "Fair", "Grim", "Harsh", "Jolly", "Noble",
        "Odd", "Pale", "Rich", "Sharp", "Tame", "Vast", "Wary", "Zany",
    ]

    private static let nouns: [String] = [
        "Dragon", "Stone", "River", "Cloud", "Leaf", "Flame", "Star", "Moon", "Sun", "Wind",
        "Wave", "Shadow", "Spark", "Frost", "Mist", "Dew", "Moss", "Fern", "Pine", "Oak",
        "Breeze", "Gale", "Storm", "Rain", "Snow", "Hail", "Fog", "Haze", "Dusk", "Dawn",
        "Brook", "Pond", "Lake", "Sea", "Cave", "Hill", "Vale", "Peak", "Grove", "Wood",
        "Berry", "Seed", "Root", "Bark", "Thorn", "Vine", "Reed", "Kelp", "Coral", "Shell",
        "Feather", "Wing", "Tail", "Horn", "Fang", "Claw", "Paw", "Eye", "Heart", "Soul",
    ]

    /// Generates a creature name of 2, 3, or 4 words with equal probability (1/3 each). Non-deterministic.
    static func generate() -> String {
        let wordCount: Int
        switch Int.random(in: 1...3) {
        case 1: wordCount = 2
        case 2: wordCount = 3
        default: wordCount = 4
        }
        var words: [String] = []
        let numAdjectives = wordCount - 1
        for _ in 0..<numAdjectives {
            words.append(adjectives.randomElement() ?? "Swift")
        }
        words.append(nouns.randomElement() ?? "Stone")
        return words.joined(separator: " ")
    }
}
