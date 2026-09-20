import AVFoundation
import Observation

@MainActor
@Observable
final class CompletionSoundPlayer {
    private(set) var errorMessage: String?
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var player: AVAudioPlayerNode?
    @ObservationIgnored private var playbackID = UUID()

    func play() {
        stop()
        errorMessage = nil
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 22_050),
                  let samples = buffer.floatChannelData?[0] else {
                errorMessage = "Completion sound unavailable."
                stop()
                return
            }
            buffer.frameLength = buffer.frameCapacity
            for index in 0..<Int(buffer.frameLength) {
                let envelope = min(1, Float(index) / 441, Float(Int(buffer.frameLength) - 1 - index) / 441)
                samples[index] = 0.35 * envelope * sin(2 * .pi * 880 * Float(index) / 44_100)
            }
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            self.engine = engine
            self.player = player
            let id = UUID()
            playbackID = id
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.playbackID == id else { return }
                    self.stop()
                }
            }
            try engine.start()
            player.play()
        } catch {
            errorMessage = "Completion sound unavailable. Check your audio output."
            stop()
        }
    }

    private func stop() {
        playbackID = UUID()
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
