import XCTest
@testable import ChemHelps

final class ChemistryDataTests: XCTestCase {
    func testAllElementsPresentAndUnique() {
        let elements = PeriodicTable.elements
        XCTAssertEqual(elements.map(\.number), Array(1...118))
        XCTAssertEqual(Set(elements.map(\.symbol)).count, 118)
    }

    func testGridHasNoOverlaps() {
        let positions = PeriodicTable.elements.map { "\($0.gridPosition.row)-\($0.gridPosition.column)" }
        XCTAssertEqual(Set(positions).count, 118)
        for element in PeriodicTable.elements {
            XCTAssert((0..<18).contains(element.gridPosition.column), element.symbol)
        }
    }

    func testGroupsAndPeriods() {
        let expected: [String: (Int?, Int)] = [
            "H": (1, 1), "He": (18, 1), "B": (13, 2), "Ne": (18, 2), "Al": (13, 3), "K": (1, 4), "Sc": (3, 4),
            "Fe": (8, 4), "Br": (17, 4), "Hf": (4, 6), "Au": (11, 6), "Rn": (18, 6), "Rf": (4, 7), "Og": (18, 7),
            "La": (nil, 6), "U": (nil, 7),
        ]
        for (symbol, (group, period)) in expected {
            let element = PeriodicTable.element(symbol)!
            XCTAssertEqual(element.group, group, symbol)
            XCTAssertEqual(element.period, period, symbol)
        }
    }

    func testElectronConfigurations() {
        let expected: [String: String] = [
            "H": "1s¹", "He": "1s²", "C": "[He] 2s² 2p²", "Na": "[Ne] 3s¹", "Cl": "[Ne] 3s² 3p⁵",
            "Fe": "[Ar] 3d⁶ 4s²", "Cr": "[Ar] 3d⁵ 4s¹", "Cu": "[Ar] 3d¹⁰ 4s¹", "Br": "[Ar] 3d¹⁰ 4s² 4p⁵",
            "Pd": "[Kr] 4d¹⁰", "Ag": "[Kr] 4d¹⁰ 5s¹", "Gd": "[Xe] 4f⁷ 5d¹ 6s²", "Au": "[Xe] 4f¹⁴ 5d¹⁰ 6s¹",
            "Pb": "[Xe] 4f¹⁴ 5d¹⁰ 6s² 6p²", "U": "[Rn] 5f³ 6d¹ 7s²", "Og": "[Rn] 5f¹⁴ 6d¹⁰ 7s² 7p⁶",
        ]
        for (symbol, text) in expected {
            XCTAssertEqual(PeriodicTable.element(symbol)!.configurationText, text, symbol)
        }
        for element in PeriodicTable.elements {
            XCTAssertEqual(element.configuration.reduce(0) { $0 + $1.electrons }, element.number, element.symbol)
        }
    }

    func testShells() {
        XCTAssertEqual(PeriodicTable.element("Na")!.shells, [2, 8, 1])
        XCTAssertEqual(PeriodicTable.element("Ca")!.shells, [2, 8, 8, 2])
        XCTAssertEqual(PeriodicTable.element("Br")!.shells, [2, 8, 18, 7])
        XCTAssertEqual(PeriodicTable.element("O")!.valenceElectrons, 6)
    }

    func testTranslationTableLoads() {
        // Doppelte Schlüssel im Wörterbuch würden hier abstürzen.
        XCTAssertEqual(MoleculeService.lookupName(for: "Essigsäure"), "acetic acid")
        XCTAssertEqual(MoleculeService.lookupName(for: " CO2 "), "carbon dioxide")
        XCTAssertEqual(MoleculeService.lookupName(for: "Koffein"), "caffeine")
        XCTAssertEqual(MoleculeService.lookupName(for: "Pyridin"), "Pyridin")
    }

    func testParsesSDF() {
        let sdf = """
        962
          -OEChem-11092613093D

          3  2  0     0  0  0  0  0  0999 V2000
            0.0000    0.0000    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0
            0.2774    0.8929    0.2544 H   0  0  0  0  0  0  0  0  0  0  0  0
            0.6068   -0.2383   -0.7169 H   0  0  0  0  0  0  0  0  0  0  0  0
          1  2  1  0  0  0  0
          1  3  1  0  0  0  0
        M  END
        """
        let molecule = Molecule.parseSDF(sdf)
        XCTAssertEqual(molecule?.atoms.count, 3)
        XCTAssertEqual(molecule?.bonds.count, 2)
        XCTAssertEqual(molecule?.formula, "H₂O")
        XCTAssertEqual(molecule?.molarMass ?? 0, 18.015, accuracy: 0.01)
        XCTAssertEqual(molecule?.is3D, true)
    }
}
