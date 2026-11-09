import SceneKit
import SwiftUI

enum MoleculeStyle: String, CaseIterable, Identifiable {
    case ballAndStick = "Kugel-Stab"
    case spaceFilling = "Kalotten"
    case sticks = "Stäbchen"

    var id: String { rawValue }
}

@MainActor
final class MoleculeState: ObservableObject {
    static let shared = MoleculeState()

    @Published var input = ""
    @Published private(set) var molecule: Molecule?
    @Published private(set) var title = ""
    @Published private(set) var isLoading = false
    @Published var error: String?
    @Published var focusRequest = 0

    private var loadTask: Task<Void, Never>?

    func load() {
        let name = input.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        loadTask?.cancel()
        isLoading = true
        error = nil
        loadTask = Task {
            do {
                let molecule = try await MoleculeService.load(name)
                guard !Task.isCancelled else { return }
                self.molecule = molecule
                self.title = name.prefix(1).uppercased() + name.dropFirst()
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
            self.isLoading = false
        }
    }
}

struct MoleculeOverlayView: View {
    @ObservedObject var state: MoleculeState
    let onClose: () -> Void

    @AppStorage("moleculeStyle") private var style = MoleculeStyle.ballAndStick
    @AppStorage("moleculeShowsHydrogen") private var showsHydrogen = true
    @AppStorage("moleculeRotates") private var rotates = true
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            controls
            ZStack {
                if let molecule = state.molecule {
                    MoleculeSceneView(molecule: molecule, style: style, showsHydrogen: showsHydrogen, rotates: rotates)
                } else if !state.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "atom")
                            .font(.system(size: 54))
                        Text("Namen eingeben, z. B. Koffein, Glucose oder Ethanol")
                    }
                    .foregroundStyle(.white.opacity(0.6))
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.35)))
                }
                if state.isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let molecule = state.molecule { caption(molecule) }
        }
        .preferredColorScheme(.dark)
        .onAppear { inputFocused = true }
        .onChange(of: state.focusRequest) { inputFocused = true }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "atom")
                    .foregroundStyle(.cyan)
                TextField("Molekül, z. B. Koffein", text: $state.input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($inputFocused)
                    .onSubmit { state.load() }
                    .frame(minWidth: 140)
                Picker("Modell", selection: $style) {
                    ForEach(MoleculeStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Toggle("H", isOn: $showsHydrogen)
                    .toggleStyle(.button)
                    .help("Wasserstoffatome zeigen")
                Toggle(isOn: $rotates) { Image(systemName: "rotate.3d") }
                    .toggleStyle(.button)
                    .help("Automatisch drehen")
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Schließen (Esc)")
            }
            if let error = state.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
        .padding(10)
    }

    private func caption(_ molecule: Molecule) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text(state.title).font(.system(size: 22, weight: .semibold))
                Text(molecule.formula).font(.system(size: 20))
                Text(String(format: "M = %.2f g/mol", molecule.molarMass).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                ForEach(legendSymbols(molecule), id: \.self) { symbol in
                    HStack(spacing: 4) {
                        Circle().fill(Color(nsColor: AtomStyle.color(symbol))).frame(width: 11, height: 11)
                        Text(PeriodicTable.element(symbol)?.name ?? symbol)
                    }
                }
                if !molecule.is3D {
                    Text("nur flache Struktur verfügbar").foregroundStyle(.orange)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        .padding(10)
    }

    private func legendSymbols(_ molecule: Molecule) -> [String] {
        var seen: [String] = []
        for atom in molecule.atoms where !seen.contains(atom.symbol) { seen.append(atom.symbol) }
        return seen.sorted { a, b in
            let order = ["C": 0, "H": 1]
            return (order[a] ?? 2, a) < (order[b] ?? 2, b)
        }
    }
}

// MARK: - SceneKit

enum AtomStyle {
    /// Farben nach dem CPK-Schema.
    static func color(_ symbol: String) -> NSColor {
        let hex: Int = switch symbol {
        case "H": 0xF2F2F2
        case "C": 0x5A5A5A
        case "N": 0x3050F8
        case "O": 0xFF2020
        case "F": 0x90E050
        case "Cl": 0x1FF01F
        case "Br": 0xA62929
        case "I": 0x940094
        case "S": 0xFFE530
        case "P": 0xFF8000
        case "Na": 0xAB5CF2
        case "K": 0x8F40D4
        case "Mg": 0x8AFF00
        case "Ca": 0x3DFF00
        case "Fe": 0xE06633
        case "Cu": 0xC88033
        case "Zn": 0x7D80B0
        case "Si": 0xF0C8A0
        case "B": 0xFFB5B5
        case "Li": 0xCC80FF
        default: 0xFF1493
        }
        return NSColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    static func covalentRadius(_ symbol: String) -> Float {
        ["H": 0.31, "C": 0.76, "N": 0.71, "O": 0.66, "F": 0.57, "P": 1.07, "S": 1.05, "Cl": 1.02,
         "Br": 1.20, "I": 1.39, "Na": 1.66, "K": 2.03, "Si": 1.11, "B": 0.84, "Mg": 1.41, "Ca": 1.76][symbol] ?? 1.2
    }

    static func vanDerWaalsRadius(_ symbol: String) -> Float {
        ["H": 1.2, "C": 1.7, "N": 1.55, "O": 1.52, "F": 1.47, "P": 1.8, "S": 1.8, "Cl": 1.75,
         "Br": 1.85, "I": 1.98, "Na": 2.27, "K": 2.75, "Si": 2.1, "B": 1.92, "Mg": 1.73, "Ca": 2.31][symbol] ?? 2.0
    }
}

struct MoleculeSceneView: NSViewRepresentable {
    let molecule: Molecule
    let style: MoleculeStyle
    let showsHydrogen: Bool
    let rotates: Bool

    final class Coordinator {
        var builtKey = ""
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        let key = "\(molecule.atoms.count)-\(molecule.radius)-\(style.rawValue)-\(showsHydrogen)"
        if context.coordinator.builtKey != key {
            context.coordinator.builtKey = key
            view.scene = MoleculeScene.make(molecule: molecule, style: style, showsHydrogen: showsHydrogen)
            view.pointOfView = view.scene?.rootNode.childNode(withName: "kamera", recursively: false)
        }
        let holder = view.scene?.rootNode.childNode(withName: "halter", recursively: false)
        if rotates, holder?.action(forKey: "drehen") == nil {
            holder?.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 14)), forKey: "drehen")
        } else if !rotates {
            holder?.removeAction(forKey: "drehen")
        }
    }
}

enum MoleculeScene {
    static func make(molecule: Molecule, style: MoleculeStyle, showsHydrogen: Bool) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear

        let holder = SCNNode()
        holder.name = "halter"
        scene.rootNode.addChildNode(holder)

        let visible = molecule.atoms.indices.filter { showsHydrogen || molecule.atoms[$0].symbol != "H" }
        let visibleSet = Set(visible)
        var materials: [String: SCNMaterial] = [:]
        func material(_ symbol: String) -> SCNMaterial {
            if let existing = materials[symbol] { return existing }
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = AtomStyle.color(symbol)
            material.roughness.contents = 0.35
            material.metalness.contents = 0.05
            materials[symbol] = material
            return material
        }

        for index in visible {
            let atom = molecule.atoms[index]
            let radius: Float = switch style {
            case .ballAndStick: 0.2 + 0.28 * AtomStyle.covalentRadius(atom.symbol)
            case .spaceFilling: AtomStyle.vanDerWaalsRadius(atom.symbol)
            case .sticks: 0.13
            }
            let sphere = SCNSphere(radius: CGFloat(radius))
            sphere.segmentCount = 48
            sphere.firstMaterial = material(atom.symbol)
            let node = SCNNode(geometry: sphere)
            node.simdPosition = atom.position
            holder.addChildNode(node)
        }

        if style != .spaceFilling {
            for bond in molecule.bonds where visibleSet.contains(bond.first) && visibleSet.contains(bond.second) {
                addBond(bond, in: molecule, style: style, to: holder, material: material)
            }
        }

        // Licht: Hauptlicht, Gegenlicht und Umgebung
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1100
        key.eulerAngles = SCNVector3(-0.6, 0.5, 0)
        scene.rootNode.addChildNode(key)
        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 450
        rim.eulerAngles = SCNVector3(0.4, -2.6, 0)
        scene.rootNode.addChildNode(rim)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 420
        scene.rootNode.addChildNode(ambient)

        let camera = SCNNode()
        camera.name = "kamera"
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 40
        let extent = molecule.radius + (style == .spaceFilling ? 2.0 : 0.8)
        let distance = extent / tan(Float(20) * .pi / 180) * 1.05
        camera.camera?.zFar = Double(distance * 4)
        camera.simdPosition = SIMD3(0, 0, distance)
        scene.rootNode.addChildNode(camera)
        return scene
    }

    private static func addBond(
        _ bond: Molecule.Bond,
        in molecule: Molecule,
        style: MoleculeStyle,
        to parent: SCNNode,
        material: (String) -> SCNMaterial
    ) {
        let a = molecule.atoms[bond.first]
        let b = molecule.atoms[bond.second]
        let axis = b.position - a.position
        let length = simd_length(axis)
        guard length > 0.01 else { return }
        let direction = axis / length

        // Mehrfachbindungen liegen nebeneinander, möglichst in der Ebene eines Nachbaratoms.
        let order = style == .sticks ? 1 : bond.order
        let offsetDirection = perpendicular(to: direction, bond: bond, in: molecule)
        let radius: Float = style == .sticks ? 0.13 : (order == 1 ? 0.085 : 0.06)
        let spacing: Float = 0.15
        let offsets: [Float] = switch order {
        case 2: [-spacing / 2, spacing / 2]
        case 3: [-spacing, 0, spacing]
        default: [0]
        }

        for offset in offsets {
            let shift = offsetDirection * offset
            // Zwei Hälften in den Farben der beiden Atome
            for (start, symbol) in [(a.position, a.symbol), (a.position + axis / 2, b.symbol)] {
                let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(length / 2))
                cylinder.radialSegmentCount = 24
                cylinder.firstMaterial = material(symbol)
                let node = SCNNode(geometry: cylinder)
                node.simdPosition = start + axis / 4 + shift
                node.simdOrientation = simd_quatf(from: SIMD3(0, 1, 0), to: direction)
                parent.addChildNode(node)
            }
        }
    }

    private static func perpendicular(to direction: SIMD3<Float>, bond: Molecule.Bond, in molecule: Molecule) -> SIMD3<Float> {
        let neighbor = molecule.bonds.first { other in
            (other.first == bond.first || other.second == bond.first) && other.first != bond.second && other.second != bond.second
        }
        var reference = SIMD3<Float>(0, 0, 1)
        if let neighbor {
            let index = neighbor.first == bond.first ? neighbor.second : neighbor.first
            reference = molecule.atoms[index].position - molecule.atoms[bond.first].position
        }
        var result = reference - simd_dot(reference, direction) * direction
        if simd_length(result) < 0.01 {
            result = simd_cross(direction, abs(direction.x) < 0.9 ? SIMD3(1, 0, 0) : SIMD3(0, 1, 0))
        }
        return simd_normalize(result)
    }
}
