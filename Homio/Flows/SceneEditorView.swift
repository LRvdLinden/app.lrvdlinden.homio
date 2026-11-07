import HomeKit
import SwiftUI

/// Een sfeer maken of bewerken: een naam en een lijst apparaten met hun stand.
struct SceneEditorView: View {
    let scene: HMActionSet?

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var flows: FlowStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var steps: [ActionStep] = []
    @State private var loaded = false
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Naam (bijv. Film kijken)", text: $name)
                }
                Section {
                    ForEach($steps) { $step in
                        ActionRow(step: $step)
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    Button {
                        if let device = home.devices.first(where: \.canBeControlled) {
                            steps.append(ActionStep.defaults(for: device))
                        }
                    } label: {
                        Label("Apparaat toevoegen", systemImage: "plus.circle.fill")
                    }
                    Button {
                        captureCurrentState()
                    } label: {
                        Label("Huidige stand van alle lampen overnemen", systemImage: "camera.metering.center.weighted")
                    }
                } header: {
                    Text("Apparaten")
                } footer: {
                    Text("Een sfeer zet al deze apparaten in één tik in de gekozen stand. Hij verschijnt ook in de Woning-app en werkt met Siri.")
                }
                if scene != nil {
                    Section {
                        Button("Probeer nu") {
                            if let scene { home.run(scene) }
                        }
                    }
                }
            }
            .navigationTitle(scene == nil ? "Nieuwe sfeer" : "Sfeer bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("Bewaar") { save() }
                            .fontWeight(.semibold)
                            .disabled(steps.isEmpty)
                    }
                }
            }
            .alert("Bewaren lukte niet", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let scene {
                    name = scene.name
                    steps = flows.steps(of: scene)
                }
            }
        }
        .interactiveDismissDisabled(saving)
    }

    private func captureCurrentState() {
        let existing = Set(steps.compactMap(\.deviceID))
        for device in home.devices where device.kind == .light && !existing.contains(device.id) {
            var step = ActionStep(deviceID: device.id)
            if device.isOn, let b = device.brightness {
                step.mode = .brightness
                step.value = b
            } else {
                step.mode = .power
                step.value = device.isOn ? 1 : 0
            }
            steps.append(step)
        }
    }

    private func save() {
        saving = true
        Task {
            do {
                try await flows.saveScene(name: name, steps: steps, existing: scene)
                saving = false
                dismiss()
            } catch {
                saving = false
                self.error = error.localizedDescription
            }
        }
    }
}
