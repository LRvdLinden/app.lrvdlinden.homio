import SwiftUI

/// Het Dashboards-tabblad: meerdere dashboards met eigen widgets, zoals een bedienpaneel.
struct DashboardsTab: View {
    let startDisplay: () -> Void

    @EnvironmentObject private var store: DashboardStore
    @EnvironmentObject private var home: HomeStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var editing = false
    @State private var showPicker = false
    @State private var showNew = false
    @State private var showRename = false
    @State private var confirmDelete = false
    @State private var nameField = ""

    var body: some View {
        NavigationStack {
            HomeStateGate {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switcher
                        if let dashboard = store.selected {
                            DashboardGridView(dashboardID: dashboard.id, editing: editing)
                            if editing {
                                Button { showPicker = true } label: {
                                    Label("Widget toevoegen", systemImage: "plus.circle.fill")
                                        .font(HomeyFont.smallMedium)
                                        .frame(maxWidth: .infinity, minHeight: 56)
                                        .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.accent.opacity(0.08)))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                                                .strokeBorder(Theme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                        )
                                }
                                .buttonStyle(PressableStyle())
                                .foregroundStyle(Theme.accent)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        } else {
                            ContentUnavailableView {
                                Label("Nog geen dashboard", systemImage: "square.grid.2x2")
                            } actions: {
                                Button("Dashboard maken") { nameField = ""; showNew = true }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding(.horizontal, sizeClass == .compact ? Theme.edge : Theme.edgeTablet)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle(store.selected?.name ?? "Dashboards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: startDisplay) {
                        Label("Weergavemodus", systemImage: "play.rectangle.fill")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if editing, let dashboard = store.selected {
                        Button { showPicker = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Widget toevoegen")
                        Menu {
                            Button {
                                nameField = dashboard.name
                                showRename = true
                            } label: { Label("Naam wijzigen", systemImage: "pencil") }
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Label("Dashboard verwijderen", systemImage: "trash")
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                    if store.selected != nil {
                        Button(editing ? "Gereed" : "Bewerk") {
                            withAnimation(.spring(response: 0.35)) { editing.toggle() }
                        }
                        .fontWeight(editing ? .semibold : .regular)
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                WidgetPickerSheet { widget in
                    if let id = store.selected?.id {
                        withAnimation(.spring(response: 0.4)) { store.add(widget, to: id) }
                    }
                }
            }
            .alert("Nieuw dashboard", isPresented: $showNew) {
                TextField("Naam, bijv. Beveiliging", text: $nameField)
                Button("Annuleer", role: .cancel) {}
                Button("Maak") {
                    store.addDashboard(named: nameField)
                    editing = true
                }
            }
            .alert("Naam wijzigen", isPresented: $showRename) {
                TextField("Naam", text: $nameField)
                Button("Annuleer", role: .cancel) {}
                Button("Bewaar") {
                    if let id = store.selected?.id { store.rename(id, to: nameField) }
                }
            }
            .confirmationDialog("Dit dashboard verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Verwijderen", role: .destructive) {
                    if let id = store.selected?.id { store.deleteDashboard(id) }
                    editing = false
                }
            }
        }
        .onAppear { if home.isReady { store.ensureDefault(home: home) } }
        .onChange(of: home.isReady) { _, ready in
            if ready { store.ensureDefault(home: home) }
        }
    }

    private var switcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.dashboards) { dashboard in
                    ZoneChip(title: dashboard.name,
                             symbol: dashboard.symbol,
                             selected: dashboard.id == store.selected?.id) {
                        withAnimation(.easeInOut(duration: 0.25)) { store.selectedID = dashboard.id }
                    }
                }
                Button {
                    nameField = ""
                    showNew = true
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(.primary)
                .accessibilityLabel("Nieuw dashboard")
            }
        }
    }
}
