import AppKit
import SceneKit
import SwiftUI

/// Prüfbilder ohne Bildschirmfoto:
/// `ChemHelps --render-table <png> [symbol]` und `ChemHelps --render-molecule <name> <png> [stil]`.
enum Snapshot {
    @MainActor
    static func runIfRequested() -> Bool {
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--render-table"), flag + 1 < arguments.count {
            let view = PeriodicTableView(onClose: {}, preview: arguments.count > flag + 2 ? PeriodicTable.element(arguments[flag + 2]) : nil)
                .frame(width: 1400, height: 860)
                .background(Color(red: 0.05, green: 0.08, blue: 0.13))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            if let image = renderer.nsImage { write(image, to: arguments[flag + 1]) }
            return true
        }
        if let flag = arguments.firstIndex(of: "--render-molecule"), flag + 2 < arguments.count {
            let style = arguments.count > flag + 3 ? MoleculeStyle(rawValue: arguments[flag + 3]) ?? .ballAndStick : .ballAndStick
            let semaphore = DispatchSemaphore(value: 0)
            var result: Molecule?
            Task.detached {
                result = try? await MoleculeService.load(arguments[flag + 1])
                semaphore.signal()
            }
            semaphore.wait()
            guard let molecule = result else { print("nicht gefunden"); return true }
            let scene = MoleculeScene.make(molecule: molecule, style: style, showsHydrogen: true)
            scene.background.contents = NSColor(white: 0.85, alpha: 1)
            let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
            renderer.scene = scene
            renderer.pointOfView = scene.rootNode.childNode(withName: "kamera", recursively: false)
            let image = renderer.snapshot(atTime: 0, with: CGSize(width: 700, height: 600), antialiasingMode: .multisampling4X)
            write(image, to: arguments[flag + 2])
            print(molecule.formula, molecule.atoms.count, "Atome", molecule.is3D ? "3D" : "2D")
            return true
        }
        return false
    }

    private static func write(_ image: NSImage, to path: String) {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
