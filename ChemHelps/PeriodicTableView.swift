import SwiftUI

enum TableColoring: String, CaseIterable, Identifiable {
    case category = "Elementgruppen"
    case electronegativity = "Elektronegativität"
    case state = "Aggregatzustand"

    var id: String { rawValue }
}

extension ElementCategory {
    var color: Color {
        switch self {
        case .alkali: Color(red: 0.93, green: 0.36, blue: 0.33)
        case .alkalineEarth: Color(red: 0.96, green: 0.62, blue: 0.27)
        case .transition: Color(red: 0.89, green: 0.75, blue: 0.36)
        case .metal: Color(red: 0.55, green: 0.70, blue: 0.62)
        case .metalloid: Color(red: 0.36, green: 0.72, blue: 0.62)
        case .nonmetal: Color(red: 0.33, green: 0.62, blue: 0.90)
        case .halogen: Color(red: 0.45, green: 0.80, blue: 0.95)
        case .nobleGas: Color(red: 0.66, green: 0.52, blue: 0.93)
        case .lanthanide: Color(red: 0.87, green: 0.50, blue: 0.70)
        case .actinide: Color(red: 0.76, green: 0.45, blue: 0.80)
        case .unknown: Color(white: 0.5)
        }
    }
}

extension MatterState {
    var color: Color {
        switch self {
        case .solid: Color(red: 0.55, green: 0.62, blue: 0.70)
        case .liquid: Color(red: 0.30, green: 0.62, blue: 0.95)
        case .gas: Color(red: 0.95, green: 0.55, blue: 0.40)
        }
    }

    var symbol: String {
        switch self {
        case .solid: "cube.fill"
        case .liquid: "drop.fill"
        case .gas: "cloud.fill"
        }
    }
}

struct PeriodicTableView: View {
    let onClose: () -> Void
    /// Nur für Prüfbilder: so tun, als läge die Maus auf diesem Element.
    var preview: Element?

    @State private var hovered: Element?
    @State private var pinned: Element?
    @AppStorage("tableColoring") private var coloring = TableColoring.category

    private static let columns = 18
    /// 7 Perioden, eine halbe Zeile Abstand, 2 f-Reihen.
    private static let rows = 9.5

    private var shown: Element? { hovered ?? pinned ?? preview }

    var body: some View {
        VStack(spacing: 10) {
            toolbar
            GeometryReader { proxy in
                let cell = floor(min(proxy.size.width / CGFloat(Self.columns), proxy.size.height / Self.rows))
                let tableWidth = cell * CGFloat(Self.columns)
                ZStack(alignment: .topLeading) {
                    detailCard(cell: cell)
                        .frame(width: cell * 10 - 8, height: cell * 3 - 8)
                        .offset(x: cell * 2 + 4, y: 4)
                    ForEach(PeriodicTable.elements) { element in
                        let position = element.gridPosition
                        ElementCell(
                            element: element,
                            cell: cell,
                            fill: fill(for: element),
                            showsElectronegativity: coloring == .electronegativity,
                            isHighlighted: shown == element,
                            isPinned: pinned == element
                        )
                        .offset(x: CGFloat(position.column) * cell, y: y(row: position.row, cell: cell))
                        .onHover { inside in
                            if inside { hovered = element } else if hovered == element { hovered = nil }
                        }
                        .onTapGesture { pinned = pinned == element ? nil : element }
                    }
                    placeholder("57–71", category: .lanthanide, row: 5, cell: cell)
                    placeholder("89–103", category: .actinide, row: 6, cell: cell)
                }
                .frame(width: tableWidth, height: cell * Self.rows, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            legend
        }
        .padding(18)
        .background {
            ZStack {
                VisualEffect(material: .hudWindow)
                Color(red: 0.05, green: 0.08, blue: 0.13).opacity(0.82)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }

    private func y(row: Int, cell: CGFloat) -> CGFloat {
        CGFloat(row >= 8 ? Double(row) - 0.5 : Double(row)) * cell
    }

    private func fill(for element: Element) -> Color {
        switch coloring {
        case .category:
            return element.category.color
        case .state:
            return element.state.color
        case .electronegativity:
            guard let value = element.electronegativity else { return Color(white: 0.35) }
            // 0,7 (blau) bis 4,0 (rot)
            let t = (value - 0.7) / 3.3
            return Color(hue: 0.62 - 0.62 * t, saturation: 0.65, brightness: 0.85)
        }
    }

    // MARK: Teile

    private var toolbar: some View {
        HStack(spacing: 14) {
            Image(systemName: "tablecells")
                .foregroundStyle(.cyan)
            Text("Periodensystem")
                .font(.title3.weight(.semibold))
            Spacer()
            Picker("Färbung", selection: $coloring) {
                ForEach(TableColoring.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Schließen (Esc)")
        }
    }

    @ViewBuilder
    private var legend: some View {
        HStack(spacing: 14) {
            switch coloring {
            case .category:
                ForEach(ElementCategory.allCases.filter { $0 != .unknown }, id: \.self) { category in
                    legendItem(category.rawValue, color: category.color)
                }
            case .state:
                ForEach([MatterState.solid, .liquid, .gas], id: \.self) { state in
                    legendItem("\(state.rawValue) bei 25 °C", color: state.color)
                }
            case .electronegativity:
                Text("0,7")
                LinearGradient(
                    colors: stride(from: 0.0, through: 1.0, by: 0.25).map {
                        Color(hue: 0.62 - 0.62 * $0, saturation: 0.65, brightness: 0.85)
                    },
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 220, height: 10)
                .clipShape(Capsule())
                Text("4,0  (Pauling)")
                legendItem("keine Angabe", color: Color(white: 0.35))
            }
            Spacer()
            Text(pinned == nil ? "Klick hält ein Element fest" : "Erneut klicken zum Lösen")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(title)
        }
    }

    private func placeholder(_ text: String, category: ElementCategory, row: Int, cell: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cell * 0.1)
            .fill(category.color.opacity(coloring == .category ? 0.35 : 0.15))
            .overlay(Text(text).font(.system(size: cell * 0.2, weight: .medium)).foregroundStyle(.secondary))
            .frame(width: cell - 3, height: cell - 3)
            .offset(x: cell * 2 + 1.5, y: CGFloat(row) * cell + 1.5)
    }

    @ViewBuilder
    private func detailCard(cell: CGFloat) -> some View {
        if let element = shown {
            ElementDetail(element: element, cell: cell, accent: fill(for: element))
        } else {
            VStack(spacing: 6) {
                Image(systemName: "cursorarrow.rays")
                    .font(.system(size: cell * 0.5))
                Text("Maus über ein Element bewegen")
                    .font(.system(size: cell * 0.26, weight: .medium))
            }
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ElementCell: View {
    let element: Element
    let cell: CGFloat
    let fill: Color
    let showsElectronegativity: Bool
    let isHighlighted: Bool
    let isPinned: Bool

    var body: some View {
        let size = cell - 3
        VStack(spacing: 0) {
            HStack {
                Text("\(element.number)")
                Spacer(minLength: 0)
                if element.isRadioactive {
                    Text("☢").opacity(0.7)
                }
            }
            .font(.system(size: cell * 0.17, weight: .medium))
            Spacer(minLength: 0)
            Text(element.symbol)
                .font(.system(size: cell * 0.38, weight: .bold))
            Spacer(minLength: 0)
            Text(showsElectronegativity ? element.electronegativityText : element.massText)
                .font(.system(size: cell * 0.15))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, cell * 0.06)
        .padding(.vertical, cell * 0.04)
        .foregroundStyle(.black.opacity(element.category == .unknown && !showsElectronegativity ? 0.55 : 0.85))
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: cell * 0.1)
                .fill(fill.opacity(isHighlighted ? 1 : 0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cell * 0.1)
                .strokeBorder(.white, lineWidth: isHighlighted ? max(2, cell * 0.04) : 0)
        )
        .overlay(alignment: .bottomTrailing) {
            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: cell * 0.13))
                    .padding(cell * 0.05)
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .scaleEffect(isHighlighted ? 1.08 : 1)
        .zIndex(isHighlighted ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: isHighlighted)
        .padding(1.5)
        .contentShape(Rectangle())
    }
}

/// Große Infokarte im freien Feld oberhalb der Übergangsmetalle.
private struct ElementDetail: View {
    let element: Element
    let cell: CGFloat
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: cell * 0.3) {
            VStack(spacing: cell * 0.04) {
                Text("\(element.number)")
                    .font(.system(size: cell * 0.3, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(element.symbol)
                    .font(.system(size: cell * 1.0, weight: .bold))
                    .minimumScaleFactor(0.5)
                Text(element.name)
                    .font(.system(size: cell * 0.22, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(cell * 0.12)
            .foregroundStyle(.black.opacity(0.85))
            .frame(width: cell * 2.4, height: cell * 2.4)
            .background(RoundedRectangle(cornerRadius: cell * 0.18).fill(accent))

            Grid(alignment: .leading, horizontalSpacing: cell * 0.2, verticalSpacing: cell * 0.06) {
                row("Atommasse", "\(element.massText) u")
                row("Elektronegativität", element.electronegativityText)
                row("Konfiguration", element.configurationText)
                row("Schalen", element.shells.map(String.init).joined(separator: " · "))
                row("Stellung", position)
                row("Art", stateText)
            }
            .font(.system(size: cell * 0.22))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .padding(cell * 0.12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: cell * 0.2).fill(.white.opacity(0.06)))
    }

    private var position: String {
        var parts: [String] = []
        if let group = element.group {
            parts.append(element.mainGroup.map { "\(group). Gruppe (\($0). HG)" } ?? "\(group). Gruppe")
        }
        parts.append("\(element.period). Periode")
        if let valence = element.valenceElectrons { parts.append("\(valence) Valenzelektronen") }
        return parts.joined(separator: " · ")
    }

    private var stateText: String {
        var text = "\(element.category.rawValue), \(element.state.rawValue)"
        if element.isRadioactive { text += ", radioaktiv" }
        return text
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).fontWeight(.medium)
        }
    }
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
