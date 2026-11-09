import Foundation

/// Wandelt eingetippte Chemie-Schreibweise in Unicode-Text um, z. B.
/// `2 H2 + O2 -> 2 H2O` → `2 H₂ + O₂ → 2 H₂O` oder `SO4^2-` → `SO₄²⁻`.
///
/// Gewöhnliche Wörter bleiben unverändert: Ziffern werden nur tiefgestellt,
/// wenn das ganze Wort aus Elementsymbolen, Klammern und Zahlen besteht.
enum FormulaConverter {
    static let elements: Set<String> = [
        "H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne", "Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar",
        "K", "Ca", "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", "Se", "Br", "Kr",
        "Rb", "Sr", "Y", "Zr", "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", "Sb", "Te", "I", "Xe",
        "Cs", "Ba", "La", "Ce", "Pr", "Nd", "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu",
        "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb", "Bi", "Po", "At", "Rn",
        "Fr", "Ra", "Ac", "Th", "Pa", "U", "Np", "Pu", "Am", "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr",
        "Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds", "Rg", "Cn", "Nh", "Fl", "Mc", "Lv", "Ts", "Og",
        // Häufige Abkürzungen in organischen Formeln
        "R", "Me", "Et", "Ph",
    ]

    private static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ", "p": "ₚ",
        "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ", "x": "ₓ",
    ]

    private static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾", "n": "ⁿ", "i": "ⁱ", "x": "ˣ", "I": "ᴵ", "V": "ⱽ",
    ]

    /// Zeichen, die schon hoch- oder tiefgestellt sind und eine Formel fortsetzen dürfen.
    private static let scriptCharacters = Set(subscripts.values).union(superscripts.values)

    /// Zustandsangaben, an denen eine Formel endet, z. B. `NaCl(aq)`.
    private static let stateSuffixes = ["(aq)", "(s)", "(l)", "(g)"]

    /// Ersetzungen vor der Formelerkennung; längere Muster zuerst.
    private static let replacements: [(String, String)] = [
        ("<=>", "⇌"), ("<->", "⇌"), ("-->", "⟶"), ("->", "→"), ("<-", "←"), ("=>", "→"),
        ("+-", "±"), ("Delta", "Δ"), ("delta", "δ"), ("deg", "°"),
    ]

    static func convert(_ text: String) -> String {
        var result = applyMarkers(text)
        for (pattern, replacement) in replacements {
            result = replaceWords(pattern, with: replacement, in: result)
        }
        result = convertFormulas(result)
        return convertElectrons(result)
    }

    // MARK: Hoch- und Tiefstellen per ^ und _

    /// `^2+` stellt hoch, `_n` stellt tief. Ein einzelnes `^` wird zu ↑ (Gas), ein einzelnes `_` zu ↓ (Niederschlag).
    private static func applyMarkers(_ text: String) -> String {
        let characters = Array(text)
        var output = ""
        var index = 0
        while index < characters.count {
            let character = characters[index]
            guard character == "^" || character == "_" else {
                output.append(character)
                index += 1
                continue
            }
            let table = character == "^" ? superscripts : subscripts
            var end = index + 1
            var converted = ""
            if end < characters.count, characters[end] == "{" {
                // Längere Angaben in geschweiften Klammern: ^{2+}, _{n+1}
                end += 1
                while end < characters.count, characters[end] != "}" {
                    converted.append(table[characters[end]] ?? characters[end])
                    end += 1
                }
                output += converted
                index = min(end + 1, characters.count)
                continue
            }
            while end < characters.count, let mapped = scriptCharacter(characters[end], table: table, isFirst: end == index + 1) {
                converted.append(mapped)
                end += 1
            }
            if converted.isEmpty {
                let isAlone = end >= characters.count || characters[end] == " " || characters[end].isPunctuation
                output.append(isAlone ? (character == "^" ? "↑" : "↓") : character)
                index += 1
            } else {
                output += converted
                index = end
            }
        }
        return output
    }

    /// Ziffern und Vorzeichen; Buchstaben nur direkt nach dem Zeichen (`_n`, `^x`).
    private static func scriptCharacter(_ character: Character, table: [Character: Character], isFirst: Bool) -> Character? {
        if character.isNumber || character == "+" || character == "-" { return table[character] }
        if isFirst, character.isLetter { return table[character] }
        return nil
    }

    // MARK: Formeln

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber)
    }

    private static func convertFormulas(_ text: String) -> String {
        let characters = Array(text)
        var output = ""
        var index = 0
        while index < characters.count {
            let atBoundary = index == 0 || !isWordCharacter(characters[index - 1])
            if atBoundary, let formula = parseFormula(characters, from: index) {
                output += formula.text
                index = formula.end
            } else {
                output.append(characters[index])
                index += 1
            }
        }
        return output
    }

    private enum Piece {
        case plain(String)
        case count(String) // Ziffern hinter einem Symbol oder einer Klammer
    }

    private static func parseFormula(_ characters: [Character], from start: Int) -> (text: String, end: Int)? {
        var pieces: [Piece] = []
        var index = start
        var elementCount = 0
        var hasGroup = false
        var lastCountFollowsBracket = false
        var expectsUnit = true // nach Koeffizient oder Kristallwasser-Punkt muss ein Symbol folgen

        func readDigits() -> String {
            var digits = ""
            while index < characters.count, characters[index].isASCII, characters[index].isNumber {
                digits.append(characters[index])
                index += 1
            }
            return digits
        }

        // Koeffizient, z. B. 2 in 2H2O
        let coefficient = readDigits()
        if !coefficient.isEmpty { pieces.append(.plain(coefficient)) }

        loop: while index < characters.count {
            let character = characters[index]
            if stateSuffixes.contains(where: { matches($0, characters, at: index) }) {
                break
            }
            switch character {
            case "A"..."Z":
                let one = String(character)
                if index + 1 < characters.count, characters[index + 1].isLowercase, characters[index + 1].isASCII,
                   elements.contains(one + String(characters[index + 1])) {
                    pieces.append(.plain(one + String(characters[index + 1])))
                    index += 2
                } else if elements.contains(one) {
                    pieces.append(.plain(one))
                    index += 1
                } else {
                    return nil
                }
                elementCount += 1
                expectsUnit = false
                let digits = readDigits()
                if !digits.isEmpty { pieces.append(.count(digits)) }
                lastCountFollowsBracket = false
            case "(", "[":
                pieces.append(.plain(String(character)))
                hasGroup = true
                index += 1
            case ")", "]":
                guard !expectsUnit else { return nil }
                pieces.append(.plain(String(character)))
                index += 1
                let digits = readDigits()
                if !digits.isEmpty { pieces.append(.count(digits)) }
                lastCountFollowsBracket = character == "]"
            case "*", "·":
                // Kristallwasser: CuSO4*5H2O
                guard elementCount > 0, index + 1 < characters.count,
                      characters[index + 1].isNumber || characters[index + 1].isUppercase else { break loop }
                pieces.append(.plain("·"))
                index += 1
                let digits = readDigits()
                if !digits.isEmpty { pieces.append(.plain(digits)) }
                expectsUnit = true
            default:
                if scriptCharacters.contains(character) {
                    pieces.append(.plain(String(character)))
                    index += 1
                } else {
                    break loop
                }
            }
        }

        guard elementCount > 0, !expectsUnit else { return nil }

        // Ladung am Ende: Na+, SO42-, Fe3+
        var charge = ""
        if index < characters.count, characters[index] == "+" || characters[index] == "-" {
            let next = index + 1
            let endsHere = next >= characters.count || !isWordCharacter(characters[next])
                && characters[next] != "+" && characters[next] != "-" && characters[next] != ">"
            if endsHere {
                charge = String(characters[index])
                index += 1
                if case .count(let digits)? = pieces.last {
                    // Einzelnes Element (Fe3+, O2-) oder Komplex ([Fe(CN)6]3-): die Zahl ist die Ladung.
                    // Mehratomig (SO42-, PO43-): nur die letzte Ziffer ist die Ladung.
                    let isMonatomic = elementCount == 1 && !hasGroup
                    if isMonatomic || lastCountFollowsBracket {
                        pieces.removeLast()
                        charge = digits + charge
                    } else if digits.count >= 2 {
                        pieces.removeLast()
                        pieces.append(.count(String(digits.dropLast())))
                        charge = String(digits.last!) + charge
                    }
                }
            }
        }

        // Die Formel muss als ganzes Wort dastehen.
        if index < characters.count, isWordCharacter(characters[index]) { return nil }

        var text = ""
        for piece in pieces {
            switch piece {
            case .plain(let value): text += value
            case .count(let digits): text += String(digits.map { subscripts[$0] ?? $0 })
            }
        }
        text += String(charge.map { superscripts[$0] ?? $0 })
        return (text, index)
    }

    // MARK: Hilfen

    private static func matches(_ pattern: String, _ characters: [Character], at index: Int) -> Bool {
        let pattern = Array(pattern)
        guard index + pattern.count <= characters.count else { return false }
        return Array(characters[index..<(index + pattern.count)]) == pattern
    }

    /// Ersetzt Muster; Muster aus Buchstaben nur als ganzes Wort.
    private static func replaceWords(_ pattern: String, with replacement: String, in text: String) -> String {
        guard pattern.first?.isLetter == true else {
            return text.replacingOccurrences(of: pattern, with: replacement)
        }
        // Dahinter darf ein Großbuchstabe folgen: DeltaH → ΔH, degC → °C.
        let expression = "(?<![A-Za-zÄÖÜäöüß])" + NSRegularExpression.escapedPattern(for: pattern) + "(?![a-zäöüß])"
        return text.replacingOccurrences(of: expression, with: replacement, options: .regularExpression)
    }

    /// Elektronen: e- → e⁻, auch mit Anzahl (2e-).
    private static func convertElectrons(_ text: String) -> String {
        text.replacingOccurrences(
            of: "(?<![A-Za-zÄÖÜäöüß])(\\d*\\s?)e-(?![A-Za-z0-9ÄÖÜäöüß])",
            with: "$1e⁻",
            options: .regularExpression
        )
    }
}
