import SwiftUI

struct WidgetSizeKey: LayoutValueKey {
    static let defaultValue: WidgetSize = .small
}

/// Raster waarin widgets 1×1, 2×1 of 2×2 cellen beslaan. Het aantal kolommen volgt de breedte.
struct DashboardGridLayout: Layout {
    var minCell: CGFloat = 160
    var spacing: CGFloat = 14
    var rowRatio: CGFloat = 0.85

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let frames = frames(for: width, subviews: subviews)
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(for: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() where index < frames.count {
            let f = frames[index]
            subview.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: f.width, height: f.height))
        }
    }

    private func frames(for width: CGFloat, subviews: Subviews) -> [CGRect] {
        let columns = max(2, min(6, Int((width + spacing) / (minCell + spacing))))
        let cell = max(40, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let rowHeight = cell * rowRatio
        var grid: [[Bool]] = []
        var result: [CGRect] = []

        for subview in subviews {
            let size = subview[WidgetSizeKey.self]
            let w = min(size.columns, columns)
            let h = size.rows
            var row = 0
            var placed = false
            while !placed {
                while grid.count < row + h {
                    grid.append(Array(repeating: false, count: columns))
                }
                for col in 0...(columns - w) where fits(grid, row: row, col: col, w: w, h: h) {
                    for r in row..<(row + h) {
                        for c in col..<(col + w) { grid[r][c] = true }
                    }
                    result.append(CGRect(x: CGFloat(col) * (cell + spacing),
                                         y: CGFloat(row) * (rowHeight + spacing),
                                         width: CGFloat(w) * cell + CGFloat(w - 1) * spacing,
                                         height: CGFloat(h) * rowHeight + CGFloat(h - 1) * spacing))
                    placed = true
                    break
                }
                row += 1
            }
        }
        return result
    }

    private func fits(_ grid: [[Bool]], row: Int, col: Int, w: Int, h: Int) -> Bool {
        for r in row..<(row + h) {
            for c in col..<(col + w) where grid[r][c] { return false }
        }
        return true
    }
}

/// Toont één dashboard. In bewerkmodus wiebelen de widgets, kun je ze slepen,
/// van formaat veranderen en verwijderen.
struct DashboardGridView: View {
    let dashboardID: UUID
    var editing = false

    @EnvironmentObject private var store: DashboardStore
    @State private var noteTarget: DashWidget?
    @State private var noteText = ""

    var body: some View {
        let widgets = store.dashboard(id: dashboardID)?.widgets ?? []
        DashboardGridLayout().callAsFunction {
            ForEach(widgets) { widget in
                WidgetView(widget: widget)
                    .allowsHitTesting(!editing)
                    .overlay {
                        if editing {
                            Color.primary.opacity(0.001)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if widget.kind == .note {
                                        noteText = widget.text
                                        noteTarget = widget
                                    }
                                }
                                .draggable(widget.id.uuidString) {
                                    WidgetDragPreview(widget: widget)
                                }
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if editing {
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    store.remove(widget.id, from: dashboardID)
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .red)
                            }
                            .offset(x: -8, y: -8)
                            .accessibilityLabel("Widget verwijderen")
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if editing {
                            Menu {
                                ForEach(WidgetSize.allCases, id: \.self) { size in
                                    Button {
                                        withAnimation(.spring(response: 0.35)) {
                                            store.resize(widget.id, to: size, in: dashboardID)
                                        }
                                    } label: {
                                        Label(size.title, systemImage: widget.size == size ? "checkmark" : size.symbol)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                                    .font(.title2)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.black, IconPalette.yellow)
                            }
                            .offset(x: 8, y: -8)
                            .accessibilityLabel("Formaat")
                        }
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let first = items.first, let id = UUID(uuidString: first) else { return false }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.move(id, onto: widget.id, in: dashboardID)
                        }
                        return true
                    }
                    .modifier(Wiggle(active: editing))
                    .layoutValue(key: WidgetSizeKey.self, value: widget.size)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: widgets)
        .alert("Notitie", isPresented: Binding(get: { noteTarget != nil }, set: { if !$0 { noteTarget = nil } })) {
            TextField("Tekst", text: $noteText)
            Button("Annuleer", role: .cancel) {}
            Button("Bewaar") {
                if let target = noteTarget { store.setText(noteText, for: target.id, in: dashboardID) }
            }
        }
    }
}

private struct WidgetDragPreview: View {
    let widget: DashWidget

    var body: some View {
        Label(widget.kind.title, systemImage: widget.kind.symbol)
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(IconPalette.orange))
            .foregroundStyle(.black)
    }
}

/// Licht wiebelen in bewerkmodus, zoals op het beginscherm.
struct Wiggle: ViewModifier {
    let active: Bool
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? (phase ? 0.9 : -0.9) : 0))
            .onChange(of: active, initial: true) { _, isActive in
                if isActive {
                    withAnimation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true)) { phase = true }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) { phase = false }
                }
            }
    }
}

/// Het dashboard als face in de weergavemodus.
struct DashboardFace: View {
    @EnvironmentObject private var store: DashboardStore
    @EnvironmentObject private var home: HomeStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            AmbientBackground(intensity: 0.35)
            HomeStateGate {
                if let dashboard = store.selected {
                    ScrollView {
                        DashboardGridView(dashboardID: dashboard.id)
                            .facePadding(sizeClass == .compact)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    ContentUnavailableView("Nog geen dashboard",
                                           systemImage: "square.grid.2x2",
                                           description: Text("Maak een dashboard in het tabblad Dashboards."))
                }
            }
        }
        .foregroundStyle(.primary)
        .onAppear { if home.isReady { store.ensureDefault(home: home) } }
    }
}
