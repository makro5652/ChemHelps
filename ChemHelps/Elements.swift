import Foundation

enum ElementCategory: String, CaseIterable {
    case alkali = "Alkalimetall"
    case alkalineEarth = "Erdalkalimetall"
    case transition = "Übergangsmetall"
    case metal = "Metall"
    case metalloid = "Halbmetall"
    case nonmetal = "Nichtmetall"
    case halogen = "Halogen"
    case nobleGas = "Edelgas"
    case lanthanide = "Lanthanoid"
    case actinide = "Actinoid"
    case unknown = "unbekannt"
}

enum MatterState: String {
    case solid = "fest"
    case liquid = "flüssig"
    case gas = "gasförmig"
}

struct Element: Identifiable, Hashable {
    let number: Int
    let symbol: String
    let name: String
    /// Mittlere Atommasse in u; bei instabilen Elementen die Massenzahl des langlebigsten Isotops.
    let mass: Double
    /// Elektronegativität nach Pauling, sofern bekannt.
    let electronegativity: Double?
    let category: ElementCategory

    var id: Int { number }

    /// Radioaktiv ohne stabiles Isotop.
    var isRadioactive: Bool { number == 43 || number == 61 || number >= 84 }

    var hasStableMass: Bool { !isRadioactive || [90, 91, 92].contains(number) }

    var massText: String {
        if !hasStableMass { return "[\(Int(mass))]" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: mass)) ?? String(mass)
    }

    var electronegativityText: String {
        guard let electronegativity else { return "–" }
        return String(format: "%.2f", electronegativity).replacingOccurrences(of: ".", with: ",")
    }

    /// Zustand bei 25 °C und Normaldruck.
    var state: MatterState {
        switch number {
        case 1, 2, 7, 8, 9, 10, 17, 18, 36, 54, 86: .gas
        case 35, 80: .liquid
        default: .solid
        }
    }

    var period: Int {
        switch number {
        case ...2: 1
        case ...10: 2
        case ...18: 3
        case ...36: 4
        case ...54: 5
        case ...86: 6
        default: 7
        }
    }

    /// Gruppe 1–18; Lanthanoide und Actinoide haben keine.
    var group: Int? {
        if (57...71).contains(number) || (89...103).contains(number) { return nil }
        let start = [1: 1, 2: 3, 3: 11, 4: 19, 5: 37, 6: 55, 7: 87][period]!
        let offset = number - start
        switch period {
        case 1: return number == 1 ? 1 : 18
        case 2, 3: return offset < 2 ? offset + 1 : offset + 11
        case 4, 5: return offset + 1
        default:
            // Periode 6 und 7: nach den 14 f-Elementen geht es mit Gruppe 4 weiter.
            if offset < 2 { return offset + 1 }
            return offset - 14 + 1
        }
    }

    /// Hauptgruppe in der Schulzählung (I–VIII), falls vorhanden.
    var mainGroup: String? {
        guard let group else { return nil }
        let roman = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
        switch group {
        case 1, 2: return roman[group - 1]
        case 13...18: return roman[group - 11]
        default: return nil
        }
    }

    /// Zeile und Spalte (beide ab 0) im Raster: 7 Perioden, darunter eine Lücke und die f-Reihen.
    var gridPosition: (row: Int, column: Int) {
        if (57...71).contains(number) { return (8, number - 57 + 2) }
        if (89...103).contains(number) { return (9, number - 89 + 2) }
        return (period - 1, (group ?? 1) - 1)
    }

    // MARK: Elektronenkonfiguration

    var configuration: [Orbital] { ElectronConfiguration.orbitals(for: number) }

    /// Kurzschreibweise mit Edelgaskern, z. B. [Ar] 3d¹⁰ 4s¹.
    var configurationText: String { ElectronConfiguration.shortText(for: number) }

    /// Elektronen je Schale (K, L, M, …), wie im Schalenmodell.
    var shells: [Int] {
        var counts = [Int](repeating: 0, count: 7)
        for orbital in configuration { counts[orbital.shell - 1] += orbital.electrons }
        return Array(counts.prefix { $0 > 0 })
    }

    /// Valenzelektronen der Hauptgruppenelemente.
    var valenceElectrons: Int? {
        guard let group else { return nil }
        switch group {
        case 1, 2: return group
        case 13...17: return group - 10
        case 18: return number == 2 ? 2 : 8
        default: return nil
        }
    }
}

struct Orbital: Hashable {
    let shell: Int
    let type: Character // s, p, d, f
    let electrons: Int

    var capacity: Int { ["s": 2, "p": 6, "d": 10, "f": 14][type]! }
    var label: String { "\(shell)\(type)" }
}

enum ElectronConfiguration {
    /// Reihenfolge der Besetzung nach der Madelung-Regel.
    private static let fillingOrder: [(Int, Character)] = [
        (1, "s"), (2, "s"), (2, "p"), (3, "s"), (3, "p"), (4, "s"), (3, "d"), (4, "p"), (5, "s"),
        (4, "d"), (5, "p"), (6, "s"), (4, "f"), (5, "d"), (6, "p"), (7, "s"), (5, "f"), (6, "d"), (7, "p"),
    ]

    /// Abweichungen von der Madelung-Regel im Grundzustand: verschobene Elektronen.
    private static let exceptions: [Int: [String: Int]] = [
        24: ["3d": 5, "4s": 1], 29: ["3d": 10, "4s": 1],
        41: ["4d": 4, "5s": 1], 42: ["4d": 5, "5s": 1], 44: ["4d": 7, "5s": 1], 45: ["4d": 8, "5s": 1],
        46: ["4d": 10, "5s": 0], 47: ["4d": 10, "5s": 1],
        57: ["4f": 0, "5d": 1], 58: ["4f": 1, "5d": 1], 64: ["4f": 7, "5d": 1],
        78: ["5d": 9, "6s": 1], 79: ["5d": 10, "6s": 1],
        89: ["5f": 0, "6d": 1], 90: ["5f": 0, "6d": 2], 91: ["5f": 2, "6d": 1], 92: ["5f": 3, "6d": 1],
        93: ["5f": 4, "6d": 1], 96: ["5f": 7, "6d": 1], 103: ["6d": 0, "7p": 1],
    ]

    private static let nobleGasCores: [(number: Int, symbol: String)] = [
        (86, "Rn"), (54, "Xe"), (36, "Kr"), (18, "Ar"), (10, "Ne"), (2, "He"),
    ]

    static func orbitals(for number: Int) -> [Orbital] {
        var remaining = number
        var filled: [String: (Int, Character, Int)] = [:]
        for (shell, type) in fillingOrder where remaining > 0 {
            let capacity = ["s": 2, "p": 6, "d": 10, "f": 14][type]!
            let electrons = min(capacity, remaining)
            filled["\(shell)\(type)"] = (shell, type, electrons)
            remaining -= electrons
        }
        for (label, electrons) in exceptions[number] ?? [:] {
            let shell = Int(String(label.first!))!
            filled[label] = (shell, label.last!, electrons)
        }
        let typeOrder: [Character: Int] = ["s": 0, "p": 1, "d": 2, "f": 3]
        return filled.values
            .filter { $0.2 > 0 }
            .map { Orbital(shell: $0.0, type: $0.1, electrons: $0.2) }
            .sorted { ($0.shell, typeOrder[$0.type]!) < ($1.shell, typeOrder[$1.type]!) }
    }

    static func shortText(for number: Int) -> String {
        let all = orbitals(for: number)
        guard let core = nobleGasCores.first(where: { $0.number < number }) else {
            return text(all)
        }
        let coreOrbitals = Set(orbitals(for: core.number))
        let rest = all.filter { !coreOrbitals.contains($0) }
        return "[\(core.symbol)] " + text(rest)
    }

    private static func text(_ orbitals: [Orbital]) -> String {
        orbitals.map { $0.label + superscript($0.electrons) }.joined(separator: " ")
    }

    private static func superscript(_ value: Int) -> String {
        let digits: [Character: Character] = [
            "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        ]
        return String(String(value).map { digits[$0]! })
    }
}

enum PeriodicTable {
    static let elements: [Element] = rawData.map { entry in
        Element(number: entry.0, symbol: entry.1, name: entry.2, mass: entry.3, electronegativity: entry.4, category: entry.5)
    }

    static func element(_ symbol: String) -> Element? {
        elements.first { $0.symbol == symbol }
    }

    private typealias Entry = (Int, String, String, Double, Double?, ElementCategory)

    private static let rawData: [Entry] = [
        (1, "H", "Wasserstoff", 1.008, 2.20, .nonmetal),
        (2, "He", "Helium", 4.0026, nil, .nobleGas),
        (3, "Li", "Lithium", 6.94, 0.98, .alkali),
        (4, "Be", "Beryllium", 9.0122, 1.57, .alkalineEarth),
        (5, "B", "Bor", 10.81, 2.04, .metalloid),
        (6, "C", "Kohlenstoff", 12.011, 2.55, .nonmetal),
        (7, "N", "Stickstoff", 14.007, 3.04, .nonmetal),
        (8, "O", "Sauerstoff", 15.999, 3.44, .nonmetal),
        (9, "F", "Fluor", 18.998, 3.98, .halogen),
        (10, "Ne", "Neon", 20.180, nil, .nobleGas),
        (11, "Na", "Natrium", 22.990, 0.93, .alkali),
        (12, "Mg", "Magnesium", 24.305, 1.31, .alkalineEarth),
        (13, "Al", "Aluminium", 26.982, 1.61, .metal),
        (14, "Si", "Silicium", 28.085, 1.90, .metalloid),
        (15, "P", "Phosphor", 30.974, 2.19, .nonmetal),
        (16, "S", "Schwefel", 32.06, 2.58, .nonmetal),
        (17, "Cl", "Chlor", 35.45, 3.16, .halogen),
        (18, "Ar", "Argon", 39.95, nil, .nobleGas),
        (19, "K", "Kalium", 39.098, 0.82, .alkali),
        (20, "Ca", "Calcium", 40.078, 1.00, .alkalineEarth),
        (21, "Sc", "Scandium", 44.956, 1.36, .transition),
        (22, "Ti", "Titan", 47.867, 1.54, .transition),
        (23, "V", "Vanadium", 50.942, 1.63, .transition),
        (24, "Cr", "Chrom", 51.996, 1.66, .transition),
        (25, "Mn", "Mangan", 54.938, 1.55, .transition),
        (26, "Fe", "Eisen", 55.845, 1.83, .transition),
        (27, "Co", "Cobalt", 58.933, 1.88, .transition),
        (28, "Ni", "Nickel", 58.693, 1.91, .transition),
        (29, "Cu", "Kupfer", 63.546, 1.90, .transition),
        (30, "Zn", "Zink", 65.38, 1.65, .transition),
        (31, "Ga", "Gallium", 69.723, 1.81, .metal),
        (32, "Ge", "Germanium", 72.630, 2.01, .metalloid),
        (33, "As", "Arsen", 74.922, 2.18, .metalloid),
        (34, "Se", "Selen", 78.971, 2.55, .nonmetal),
        (35, "Br", "Brom", 79.904, 2.96, .halogen),
        (36, "Kr", "Krypton", 83.798, 3.00, .nobleGas),
        (37, "Rb", "Rubidium", 85.468, 0.82, .alkali),
        (38, "Sr", "Strontium", 87.62, 0.95, .alkalineEarth),
        (39, "Y", "Yttrium", 88.906, 1.22, .transition),
        (40, "Zr", "Zirconium", 91.224, 1.33, .transition),
        (41, "Nb", "Niob", 92.906, 1.6, .transition),
        (42, "Mo", "Molybdän", 95.95, 2.16, .transition),
        (43, "Tc", "Technetium", 98, 1.9, .transition),
        (44, "Ru", "Ruthenium", 101.07, 2.2, .transition),
        (45, "Rh", "Rhodium", 102.91, 2.28, .transition),
        (46, "Pd", "Palladium", 106.42, 2.20, .transition),
        (47, "Ag", "Silber", 107.87, 1.93, .transition),
        (48, "Cd", "Cadmium", 112.41, 1.69, .transition),
        (49, "In", "Indium", 114.82, 1.78, .metal),
        (50, "Sn", "Zinn", 118.71, 1.96, .metal),
        (51, "Sb", "Antimon", 121.76, 2.05, .metalloid),
        (52, "Te", "Tellur", 127.60, 2.1, .metalloid),
        (53, "I", "Iod", 126.90, 2.66, .halogen),
        (54, "Xe", "Xenon", 131.29, 2.6, .nobleGas),
        (55, "Cs", "Caesium", 132.91, 0.79, .alkali),
        (56, "Ba", "Barium", 137.33, 0.89, .alkalineEarth),
        (57, "La", "Lanthan", 138.91, 1.10, .lanthanide),
        (58, "Ce", "Cer", 140.12, 1.12, .lanthanide),
        (59, "Pr", "Praseodym", 140.91, 1.13, .lanthanide),
        (60, "Nd", "Neodym", 144.24, 1.14, .lanthanide),
        (61, "Pm", "Promethium", 145, 1.13, .lanthanide),
        (62, "Sm", "Samarium", 150.36, 1.17, .lanthanide),
        (63, "Eu", "Europium", 151.96, 1.2, .lanthanide),
        (64, "Gd", "Gadolinium", 157.25, 1.20, .lanthanide),
        (65, "Tb", "Terbium", 158.93, 1.1, .lanthanide),
        (66, "Dy", "Dysprosium", 162.50, 1.22, .lanthanide),
        (67, "Ho", "Holmium", 164.93, 1.23, .lanthanide),
        (68, "Er", "Erbium", 167.26, 1.24, .lanthanide),
        (69, "Tm", "Thulium", 168.93, 1.25, .lanthanide),
        (70, "Yb", "Ytterbium", 173.05, 1.1, .lanthanide),
        (71, "Lu", "Lutetium", 174.97, 1.27, .lanthanide),
        (72, "Hf", "Hafnium", 178.49, 1.3, .transition),
        (73, "Ta", "Tantal", 180.95, 1.5, .transition),
        (74, "W", "Wolfram", 183.84, 2.36, .transition),
        (75, "Re", "Rhenium", 186.21, 1.9, .transition),
        (76, "Os", "Osmium", 190.23, 2.2, .transition),
        (77, "Ir", "Iridium", 192.22, 2.20, .transition),
        (78, "Pt", "Platin", 195.08, 2.28, .transition),
        (79, "Au", "Gold", 196.97, 2.54, .transition),
        (80, "Hg", "Quecksilber", 200.59, 2.00, .transition),
        (81, "Tl", "Thallium", 204.38, 1.62, .metal),
        (82, "Pb", "Blei", 207.2, 2.33, .metal),
        (83, "Bi", "Bismut", 208.98, 2.02, .metal),
        (84, "Po", "Polonium", 209, 2.0, .metal),
        (85, "At", "Astat", 210, 2.2, .halogen),
        (86, "Rn", "Radon", 222, 2.2, .nobleGas),
        (87, "Fr", "Francium", 223, 0.7, .alkali),
        (88, "Ra", "Radium", 226, 0.9, .alkalineEarth),
        (89, "Ac", "Actinium", 227, 1.1, .actinide),
        (90, "Th", "Thorium", 232.04, 1.3, .actinide),
        (91, "Pa", "Protactinium", 231.04, 1.5, .actinide),
        (92, "U", "Uran", 238.03, 1.38, .actinide),
        (93, "Np", "Neptunium", 237, 1.36, .actinide),
        (94, "Pu", "Plutonium", 244, 1.28, .actinide),
        (95, "Am", "Americium", 243, 1.13, .actinide),
        (96, "Cm", "Curium", 247, 1.28, .actinide),
        (97, "Bk", "Berkelium", 247, 1.3, .actinide),
        (98, "Cf", "Californium", 251, 1.3, .actinide),
        (99, "Es", "Einsteinium", 252, 1.3, .actinide),
        (100, "Fm", "Fermium", 257, 1.3, .actinide),
        (101, "Md", "Mendelevium", 258, 1.3, .actinide),
        (102, "No", "Nobelium", 259, 1.3, .actinide),
        (103, "Lr", "Lawrencium", 266, nil, .actinide),
        (104, "Rf", "Rutherfordium", 267, nil, .transition),
        (105, "Db", "Dubnium", 268, nil, .transition),
        (106, "Sg", "Seaborgium", 269, nil, .transition),
        (107, "Bh", "Bohrium", 270, nil, .transition),
        (108, "Hs", "Hassium", 269, nil, .transition),
        (109, "Mt", "Meitnerium", 278, nil, .unknown),
        (110, "Ds", "Darmstadtium", 281, nil, .unknown),
        (111, "Rg", "Roentgenium", 282, nil, .unknown),
        (112, "Cn", "Copernicium", 285, nil, .unknown),
        (113, "Nh", "Nihonium", 286, nil, .unknown),
        (114, "Fl", "Flerovium", 289, nil, .unknown),
        (115, "Mc", "Moscovium", 290, nil, .unknown),
        (116, "Lv", "Livermorium", 293, nil, .unknown),
        (117, "Ts", "Tenness", 294, nil, .unknown),
        (118, "Og", "Oganesson", 294, nil, .unknown),
    ]
}
