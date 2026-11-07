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
        VStack(alignment: .leading, spacing: Theme.su * 1.5) {
            HStack(alignment: .top) {
                Image(systemName: device.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(on ? Color.white : Color.secondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(on ? AnyShapeStyle(device.tint.gradient) : AnyShapeStyle(Theme.pill)))
                    .contentTransition(.symbolEffect(.replace))
                Spacer()
                if !device.isReachable {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(HomeyFont.small)
                        .foregroundStyle(Theme.orange)
                } else if device.isToggleable {
                    Circle()
                        .fill(on ? device.tint : Theme.line)
                        .frame(width: 8, height: 8)
                        .padding(6)
                }
            }
            Spacer(minLength: Theme.su)
            Text(device.name)
                .font(HomeyFont.bodyMedium)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(device.stateText)
                .font(HomeyFont.small)
                .foregroundStyle(on ? device.tint : Color.secondary)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .padding(Theme.su * 4)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                        .fill(device.tint.opacity(on ? 0.12 : 0))
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                .strokeBorder(on ? device.tint.opacity(0.5) : Theme.line, lineWidth: 1)
        }
        .scaleEffect(pressing ? 0.95 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressing)
        .animation(.easeInOut(duration: 0.25), value: on)
        .contentShape(RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous))
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
            .glassCard()
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.primary)
        .sensoryFeedback(.success, trigger: fired)
    }
}
