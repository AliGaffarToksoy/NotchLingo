import AVFoundation
import Speech
import SwiftUI

/// Recognition is always on device; unsupported locales never fall back to a server.
@MainActor final class AudioService: ObservableObject {
    @Published var transcript = ""
    @Published var recording = false
    @Published var error: String?
    private let synthesizer = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var timeout: Task<Void, Never>?
    private var hasTap = false
    private var generation = UUID()

    func speak(_ text: String, locale: String) {
        stop()
        let available = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == locale }
        guard let voice = available.first else {
            error = "No offline voice for \(locale). Add an English voice in System Settings → Accessibility → Spoken Content. / İngilizce sistem sesi yükleyin."
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice; utterance.rate = 0.43
        synthesizer.speak(utterance)
    }
    func begin(locale: String) async {
        stop(); error = nil; transcript = ""
        let token = UUID(); generation = token
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        guard mic else { error = "Microphone access denied. / Mikrofon izni verilmedi. System Settings → Privacy & Security → Microphone."; return }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard generation == token else { return }
        guard status == .authorized else { error = "Speech recognition permission is required. / Konuşma tanıma izni gerekiyor."; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
              recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            error = "Offline speech recognition is unavailable for this voice on this Mac. Try US English. / Bu Mac'te çevrimdışı konuşma tanıma kullanılamıyor; ABD İngilizcesini deneyin."
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let bufferRequest = SFSpeechAudioBufferRecognitionRequest()
        bufferRequest.requiresOnDeviceRecognition = true
        bufferRequest.shouldReportPartialResults = true
        request = bufferRequest
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { error = "No microphone available. / Mikrofon bulunamadı."; return }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in bufferRequest.append(buffer) }
        hasTap = true
        recognition = recognizer.recognitionTask(with: bufferRequest) { [weak self] result, failure in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                if let result { self.transcript = result.bestTranscription.formattedString }
                if let failure, self.recording { self.error = failure.localizedDescription }
                if failure != nil || result?.isFinal == true { self.stop() }
            }
        }
        do {
            engine.prepare(); try engine.start(); recording = true
            timeout = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                guard !Task.isCancelled else { return }
                self?.finish()
            }
        } catch { self.error = error.localizedDescription; stop() }
    }
    func finish() {
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio(); recording = false; timeout?.cancel()
    }
    func stop() {
        generation = UUID(); finish(); recognition?.cancel(); recognition = nil; request = nil
    }
    func stopAll() { stop(); synthesizer.stopSpeaking(at: .immediate) }
}
