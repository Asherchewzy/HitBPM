import SwiftUI

@main
struct LiveBPMApp: App {
    @State private var bluetoothManager = BluetoothHeartRateManager()

    var body: some Scene {
        WindowGroup {
            ContentView(bluetoothManager: bluetoothManager)
        }
    }
}
