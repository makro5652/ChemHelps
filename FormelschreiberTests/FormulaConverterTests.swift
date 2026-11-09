import XCTest
@testable import Formelschreiber

final class FormulaConverterTests: XCTestCase {
    private func check(_ input: String, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(FormulaConverter.convert(input), expected, file: file, line: line)
    }

    func testSimpleFormulas() {
        check("H2O", "H₂O")
        check("CO2", "CO₂")
        check("C6H12O6", "C₆H₁₂O₆")
        check("Ca(OH)2", "Ca(OH)₂")
        check("(NH4)2SO4", "(NH₄)₂SO₄")
        check("2H2O", "2H₂O")
    }

    func testEquations() {
        check("2 H2 + O2 -> 2 H2O", "2 H₂ + O₂ → 2 H₂O")
        check("N2 + 3 H2 <=> 2 NH3", "N₂ + 3 H₂ ⇌ 2 NH₃")
        check("6 CO2 + 6 H2O -> C6H12O6 + 6 O2", "6 CO₂ + 6 H₂O → C₆H₁₂O₆ + 6 O₂")
    }

    func testCharges() {
        check("Na+ + Cl-", "Na⁺ + Cl⁻")
        check("Fe3+", "Fe³⁺")
        check("O2-", "O²⁻")
        check("NH4+", "NH₄⁺")
        check("SO42-", "SO₄²⁻")
        check("PO43-", "PO₄³⁻")
        check("HCO3-", "HCO₃⁻")
        check("H3O+", "H₃O⁺")
        check("[Fe(CN)6]3-", "[Fe(CN)₆]³⁻")
    }

    func testExplicitMarkers() {
        check("SO4^2-", "SO₄²⁻")
        check("Fe^3+", "Fe³⁺")
        check("^14C", "¹⁴C")
        check("CO2 ^", "CO₂ ↑")
        check("AgCl _", "AgCl ↓")
        check("C_n H_{2n+2}", "Cₙ H₂ₙ₊₂")
        check("x^2", "x²")
    }

    func testSpecialSymbols() {
        check("CuSO4*5H2O", "CuSO₄·5H₂O")
        check("DeltaH < 0", "ΔH < 0")
        check("25 degC", "25 °C")
        check("2 e-", "2 e⁻")
        check("Cu2+ + 2e- -> Cu", "Cu²⁺ + 2e⁻ → Cu")
        check("NaCl(aq)", "NaCl(aq)")
        check("H2O(l)", "H₂O(l)")
    }

    func testOrdinaryTextStaysUntouched() {
        check("Ich habe 3 Kapitel gelesen.", "Ich habe 3 Kapitel gelesen.")
        check("Natrium reagiert mit Wasser", "Natrium reagiert mit Wasser")
        check("Seite 12, Aufgabe 4a", "Seite 12, Aufgabe 4a")
        check("das CO2-Molekül", "das CO₂-Molekül")
        check("Bio-Unterricht und E-Mail", "Bio-Unterricht und E-Mail")
        check("A4-Blatt", "A4-Blatt")
        check("(siehe oben)", "(siehe oben)")
        check("Der pH-Wert ist 7", "Der pH-Wert ist 7")
    }
}
