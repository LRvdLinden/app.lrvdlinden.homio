import SwiftUI

/// Tegel voor één apparaat. Tik = aan/uit, lang drukken = details.
struct DeviceTile: View {
    let device: Device
    var minHeight: CGFloat = 132
    var fillsHeight = false

    @EnvironmentObject private var home: HomeStore
    @State private var showDetail = false
    @State private var pressing = false

    var body: some View {
        let on = device.isOn && !device.kind.isSensor
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: device.symbol)
                    .font(.title2)
                    .foregroundStyle(on ? device.tint : .white.opacity(0.85))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(on ? device.tint.opacity(0.2) : .white.opacity(0.1)))
                    .contentTransition(.symbolEffect(.replace))
                Spacer()
                if !device.isReachable {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                }
            }
            Spacer(minLength: 4)
            Text(device.name)
                .font(.headline)
                .lineLimit(2)
            Text(device.stateText)
                .font(.subheadline)
                .foregroundStyle(on ? Color.black.opacity(0.55) : Color.white.opacity(0.6))
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .foregroundStyle(on ? Color.black : Color.white)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(on ? AnyShapeStyle(Color.white.opacity(0.93)) : AnyShapeStyle(.ultraThinMaterial))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(on ? 0 : 0.08), lineWidth: 1)
        }
        .scaleEffect(pressing ? 0.95 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressing)
        .animation(.easeInOut(duration: 0.25), value: on)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            if device.isToggleable { home.toggle(device) } else { showDetail = true }
        }
        .onLongPressGesture(minimumDuration: 0.4, perform: {
            showDetail = true
        }, onPressingChanged: { isPressing in
            pressing = isPressing
        })
        .sensoryFeedback(.impact(weight: .light), trigger: on)
        .sheet(isPresented: $showDetail) {
            DeviceDetailSheet(deviceID: device.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Knop voor een scène.
struct SceneChip: View {
    let name: String
    let symbol: String
    let action: () -> Void
    @State private var fired = false

    var body: some View {
        Button {
            action()
            fired.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(Theme.amber)
                    .symbolEffect(.bounce, value: fired)
                Text(name).font(.headline).lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassCard(corner: 20)
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.white)
        .sensoryFeedback(.success, trigger: fired)
    }
}
