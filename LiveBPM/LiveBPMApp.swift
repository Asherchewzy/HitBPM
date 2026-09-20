import SwiftUI

@main
struct LiveBPMApp: App {
    @State private var bluetoothManager: BluetoothHeartRateManager
    @State private var intervalController: IntervalController
    @State private var soundPlayer: CompletionSoundPlayer
    private let settingsStore = IntervalSettingsStore()

    init() {
        let soundPlayer = CompletionSoundPlayer()
        let controller = IntervalController(
            settings: IntervalSettingsStore().load(),
            onComplete: { soundPlayer.play() }
        )
        let manager = BluetoothHeartRateManager()
        manager.onHeartRate = { [weak controller] bpm in
            controller?.receiveHeartRate(bpm)
        }
        _bluetoothManager = State(initialValue: manager)
        _intervalController = State(initialValue: controller)
        _soundPlayer = State(initialValue: soundPlayer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                bluetoothManager: bluetoothManager,
                intervalController: intervalController,
                soundPlayer: soundPlayer,
                onSettingsChanged: settingsStore.save
            )
        }
    }
}
