import SwiftUI

struct ContentView: View {
    @Bindable var bluetoothManager: BluetoothHeartRateManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    statusSection
                    heartRateSection
                    deviceSection
                    controlsSection
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("LiveBPM")
        }
    }

    private var statusSection: some View {
        VStack(spacing: 8) {
            Label(
                bluetoothManager.connectionState.title,
                systemImage: statusSymbol
            )
            .font(.headline)
            .foregroundStyle(statusColor)

            if case let .connectionFailed(message) = bluetoothManager.connectionState {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let deviceName = bluetoothManager.selectedDeviceName {
                Text(deviceName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var heartRateSection: some View {
        VStack(spacing: 4) {
            Text(bluetoothManager.heartRate.map(String.init) ?? "—")
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .accessibilityLabel("Heart rate")
                .accessibilityValue(heartRateAccessibilityValue)

            Text("BPM")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var deviceSection: some View {
        if !bluetoothManager.discoveredDevices.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Heart-rate devices")
                    .font(.headline)

                ForEach(bluetoothManager.discoveredDevices) { device in
                    Button {
                        bluetoothManager.selectDevice(id: device.id)
                    } label: {
                        HStack {
                            Image(systemName: bluetoothManager.selectedDeviceID == device.id
                                  ? "checkmark.circle.fill"
                                  : "circle")
                            Text(device.name)
                            Spacer()
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(
                        bluetoothManager.selectedDeviceID == device.id ? "Selected" : "Not selected"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.quaternary, in: .rect(cornerRadius: 16))
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 12) {
            Button {
                bluetoothManager.scan()
            } label: {
                Label("Scan for devices", systemImage: "dot.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!bluetoothManager.isBluetoothAvailable)

            if bluetoothManager.selectedDeviceID != nil,
               bluetoothManager.connectionState != .connected,
               bluetoothManager.connectionState != .connecting {
                Button("Connect") {
                    bluetoothManager.connect()
                }
                .buttonStyle(.bordered)
            }

            if bluetoothManager.connectionState == .connected
                || bluetoothManager.connectionState == .connecting {
                Button("Disconnect", role: .destructive) {
                    bluetoothManager.disconnect()
                }
                .buttonStyle(.bordered)
            }

            if bluetoothManager.connectionState == .disconnected
                || isConnectionFailure {
                Button("Retry") {
                    bluetoothManager.retry()
                }
                .buttonStyle(.bordered)
            }

            if bluetoothManager.connectionState == .scanning {
                ProgressView("Looking for Heart Rate Service devices…")
            }
        }
        .controlSize(.large)
    }

    private var isConnectionFailure: Bool {
        if case .connectionFailed = bluetoothManager.connectionState {
            return true
        }
        return false
    }

    private var statusSymbol: String {
        switch bluetoothManager.connectionState {
        case .connected:
            "heart.fill"
        case .scanning, .deviceFound, .connecting:
            "wave.3.right"
        case .bluetoothUnavailable, .connectionFailed:
            "exclamationmark.triangle.fill"
        case .idle, .disconnected:
            "heart"
        }
    }

    private var statusColor: Color {
        switch bluetoothManager.connectionState {
        case .connected:
            .green
        case .bluetoothUnavailable, .connectionFailed:
            .red
        case .scanning, .deviceFound, .connecting:
            .blue
        case .idle, .disconnected:
            .secondary
        }
    }

    private var heartRateAccessibilityValue: String {
        guard let heartRate = bluetoothManager.heartRate else {
            return "No reading"
        }
        return "\(heartRate) beats per minute"
    }
}

#Preview {
    ContentView(bluetoothManager: BluetoothHeartRateManager())
}
