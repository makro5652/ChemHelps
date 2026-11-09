import Foundation
import simd

struct Molecule {
    struct Atom {
        let symbol: String
        var position: SIMD3<Float>
    }

    struct Bond {
        let first: Int
        let second: Int
        let order: Int
    }

    var atoms: [Atom]
    var bonds: [Bond]
    /// False, wenn PubChem nur eine flache Struktur hatte.
    var is3D: Bool

    /// Summenformel in Hill-Schreibweise: C, H, dann alphabetisch.
    var formula: String {
        var counts: [String: Int] = [:]
        for atom in atoms { counts[atom.symbol, default: 0] += 1 }
        var order = counts.keys.sorted()
        if counts["C"] != nil {
            order.removeAll { $0 == "C" || $0 == "H" }
            order = ["C"] + (counts["H"] != nil ? ["H"] : []) + order
        }
        let plain = order.map { $0 + (counts[$0]! > 1 ? String(counts[$0]!) : "") }.joined()
        return FormulaConverter.convert(plain)
    }

    /// Molare Masse in g/mol aus den Atommassen des Periodensystems.
    var molarMass: Double {
        atoms.reduce(0) { $0 + (PeriodicTable.element($1.symbol)?.mass ?? 0) }
    }

    /// Liest eine Molfile/SDF-Datei (V2000).
    static func parseSDF(_ text: String) -> Molecule? {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count > 4 else { return nil }
        let counts = lines[3]
        guard let atomCount = Int(field(counts, 0, 3)), let bondCount = Int(field(counts, 3, 6)),
              atomCount > 0, lines.count >= 4 + atomCount + bondCount else { return nil }
        var atoms: [Atom] = []
        var hasDepth = false
        for line in lines[4..<(4 + atomCount)] {
            guard let x = Float(field(line, 0, 10)), let y = Float(field(line, 10, 20)),
                  let z = Float(field(line, 20, 30)) else { return nil }
            let symbol = field(line, 31, 34)
            if abs(z) > 0.0001 { hasDepth = true }
            atoms.append(Atom(symbol: symbol, position: SIMD3(x, y, z)))
        }
        var bonds: [Bond] = []
        for line in lines[(4 + atomCount)..<(4 + atomCount + bondCount)] {
            guard let a = Int(field(line, 0, 3)), let b = Int(field(line, 3, 6)), let order = Int(field(line, 6, 9)),
                  a >= 1, b >= 1, a <= atomCount, b <= atomCount else { continue }
            bonds.append(Bond(first: a - 1, second: b - 1, order: min(max(order, 1), 3)))
        }
        var molecule = Molecule(atoms: atoms, bonds: bonds, is3D: hasDepth || atomCount <= 2)
        molecule.center()
        return molecule
    }

    private static func field(_ line: String, _ start: Int, _ end: Int) -> String {
        let characters = Array(line)
        guard start < characters.count else { return "" }
        return String(characters[start..<min(end, characters.count)]).trimmingCharacters(in: .whitespaces)
    }

    private mutating func center() {
        guard !atoms.isEmpty else { return }
        let middle = atoms.reduce(SIMD3<Float>.zero) { $0 + $1.position } / Float(atoms.count)
        for index in atoms.indices { atoms[index].position -= middle }
    }

    var radius: Float {
        atoms.map { simd_length($0.position) }.max() ?? 1
    }
}

enum MoleculeError: LocalizedError {
    case notFound(String)
    case offline
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notFound(let name): "„\(name)“ wurde bei PubChem nicht gefunden. Englischer Name probieren?"
        case .offline: "Keine Verbindung zu PubChem."
        case .unreadable: "Die Struktur ließ sich nicht lesen."
        }
    }
}

/// Lädt Strukturen von PubChem und hält sie im Cache, damit bekannte Moleküle auch offline gehen.
enum MoleculeService {
    /// Deutsche Schulnamen und Formeln, die PubChem nicht kennt.
    static let translations: [String: String] = [
        "wasser": "water", "h2o": "water",
        "kohlenstoffdioxid": "carbon dioxide", "kohlendioxid": "carbon dioxide", "co2": "carbon dioxide",
        "kohlenstoffmonoxid": "carbon monoxide", "kohlenmonoxid": "carbon monoxide", "co": "carbon monoxide",
        "sauerstoff": "oxygen", "o2": "oxygen", "stickstoff": "nitrogen", "n2": "nitrogen",
        "wasserstoff": "hydrogen", "h2": "hydrogen", "ozon": "ozone", "o3": "ozone",
        "chlor": "chlorine", "cl2": "chlorine", "brom": "bromine", "iod": "iodine", "jod": "iodine",
        "methan": "methane", "ch4": "methane", "ethan": "ethane", "propan": "propane", "butan": "butane",
        "pentan": "pentane", "hexan": "hexane", "heptan": "heptane", "octan": "octane", "oktan": "octane",
        "ethen": "ethylene", "ethylen": "ethylene", "propen": "propene", "ethin": "acetylene", "acetylen": "acetylene",
        "benzol": "benzene", "toluol": "toluene", "naphthalin": "naphthalene", "cyclohexan": "cyclohexane",
        "ammoniak": "ammonia", "nh3": "ammonia",
        "salzsäure": "hydrogen chloride", "chlorwasserstoff": "hydrogen chloride", "hcl": "hydrogen chloride",
        "schwefelsäure": "sulfuric acid", "h2so4": "sulfuric acid", "schweflige säure": "sulfurous acid",
        "salpetersäure": "nitric acid", "hno3": "nitric acid", "phosphorsäure": "phosphoric acid", "h3po4": "phosphoric acid",
        "kohlensäure": "carbonic acid", "h2co3": "carbonic acid",
        "essigsäure": "acetic acid", "ethansäure": "acetic acid", "ameisensäure": "formic acid", "methansäure": "formic acid",
        "propansäure": "propionic acid", "buttersäure": "butyric acid", "butansäure": "butyric acid",
        "zitronensäure": "citric acid", "citronensäure": "citric acid", "milchsäure": "lactic acid",
        "oxalsäure": "oxalic acid", "weinsäure": "tartaric acid", "apfelsäure": "malic acid",
        "ascorbinsäure": "ascorbic acid", "vitamin c": "ascorbic acid", "salicylsäure": "salicylic acid",
        "benzoesäure": "benzoic acid", "stearinsäure": "stearic acid", "ölsäure": "oleic acid", "palmitinsäure": "palmitic acid",
        "brenztraubensäure": "pyruvic acid", "glutaminsäure": "glutamic acid", "asparaginsäure": "aspartic acid",
        "methanol": "methanol", "ethanol": "ethanol", "c2h5oh": "ethanol", "propanol": "1-propanol",
        "butanol": "1-butanol", "glycerin": "glycerol", "glyzerin": "glycerol",
        "methanal": "formaldehyde", "formaldehyd": "formaldehyde", "ethanal": "acetaldehyde", "acetaldehyd": "acetaldehyde",
        "propanon": "acetone", "aceton": "acetone",
        "glucose": "glucose", "glukose": "glucose", "traubenzucker": "glucose", "c6h12o6": "glucose",
        "fructose": "fructose", "fruktose": "fructose", "fruchtzucker": "fructose",
        "saccharose": "sucrose", "rohrzucker": "sucrose", "haushaltszucker": "sucrose",
        "maltose": "maltose", "malzzucker": "maltose", "lactose": "lactose", "laktose": "lactose", "milchzucker": "lactose",
        "harnstoff": "urea", "koffein": "caffeine", "coffein": "caffeine", "nikotin": "nicotine",
        "wasserstoffperoxid": "hydrogen peroxide", "h2o2": "hydrogen peroxide",
        "schwefeldioxid": "sulfur dioxide", "so2": "sulfur dioxide", "schwefeltrioxid": "sulfur trioxide",
        "schwefelwasserstoff": "hydrogen sulfide", "h2s": "hydrogen sulfide",
        "stickstoffdioxid": "nitrogen dioxide", "no2": "nitrogen dioxide", "stickstoffmonoxid": "nitric oxide",
        "lachgas": "nitrous oxide", "distickstoffmonoxid": "nitrous oxide",
        "cholesterin": "cholesterol", "adrenalin": "epinephrine", "noradrenalin": "norepinephrine",
        "paracetamol": "acetaminophen", "aspirin": "aspirin", "acetylsalicylsäure": "aspirin",
        "chlorophyll": "chlorophyll a", "häm": "heme", "carotin": "beta-carotene", "beta-carotin": "beta-carotene",
        "glycin": "glycine", "alanin": "alanine", "valin": "valine", "leucin": "leucine", "isoleucin": "isoleucine",
        "serin": "serine", "threonin": "threonine", "cystein": "cysteine", "methionin": "methionine",
        "phenylalanin": "phenylalanine", "tyrosin": "tyrosine", "tryptophan": "tryptophan", "prolin": "proline",
        "lysin": "lysine", "arginin": "arginine", "histidin": "histidine", "glutamin": "glutamine", "asparagin": "asparagine",
        "adenin": "adenine", "guanin": "guanine", "cytosin": "cytosine", "thymin": "thymine", "uracil": "uracil",
        "ribose": "ribose", "desoxyribose": "deoxyribose", "atp": "adenosine triphosphate",
        "adenosintriphosphat": "adenosine triphosphate", "nad": "nicotinamide adenine dinucleotide",
        "phenol": "phenol", "anilin": "aniline", "styrol": "styrene", "vanillin": "vanillin", "menthol": "menthol",
        "limonen": "limonene", "testosteron": "testosterone", "östradiol": "estradiol", "dopamin": "dopamine",
        "serotonin": "serotonin", "melatonin": "melatonin", "insulin": "insulin", "ibuprofen": "ibuprofen",
        "chloroform": "chloroform", "trichlormethan": "chloroform", "tetrachlormethan": "carbon tetrachloride",
        "dichlormethan": "dichloromethane", "chlormethan": "chloromethane",
        "ethylenglykol": "ethylene glycol", "ethandiol": "ethylene glycol", "diethylether": "diethyl ether",
        "essigsäureethylester": "ethyl acetate", "ethylacetat": "ethyl acetate", "harnsäure": "uric acid",
    ]

    static func lookupName(for input: String) -> String {
        let key = input.trimmingCharacters(in: .whitespaces).lowercased()
        return translations[key] ?? input.trimmingCharacters(in: .whitespaces)
    }

    private static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("de.makro.ChemHelps/Molekuele", isDirectory: true)
    }

    static func load(_ input: String) async throws -> Molecule {
        let name = lookupName(for: input)
        let cacheFile = cacheDirectory.appendingPathComponent(name.lowercased().replacingOccurrences(of: "/", with: "_") + ".sdf")
        if let cached = try? String(contentsOf: cacheFile, encoding: .utf8), let molecule = Molecule.parseSDF(cached) {
            return molecule
        }
        for recordType in ["3d", "2d"] {
            guard let text = try await fetch(name: name, recordType: recordType) else { continue }
            guard let molecule = Molecule.parseSDF(text) else { throw MoleculeError.unreadable }
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try? text.write(to: cacheFile, atomically: true, encoding: .utf8)
            return molecule
        }
        throw MoleculeError.notFound(input)
    }

    /// Nil, wenn PubChem den Namen oder diese Darstellung nicht kennt.
    private static func fetch(name: String, recordType: String) async throws -> String? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/\(encoded)/SDF?record_type=\(recordType)")
        else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MoleculeError.offline
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        // PubChem liefert bei mehreren Treffern mehrere Datensätze; der erste genügt.
        let text = String(decoding: data, as: UTF8.self)
        return text.components(separatedBy: "$$$$").first
    }
}
