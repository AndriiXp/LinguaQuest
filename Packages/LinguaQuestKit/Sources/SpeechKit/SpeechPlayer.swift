import Foundation
import AVFoundation
import Observation

/// Озвучка учебных фраз системным синтезатором.
///
/// Отдельных аудиофайлов в Фазе 1 нет: голос системы бесплатен, доступен офлайн
/// и позволяет добавлять контент, не записывая дикторов.
@MainActor
@Observable
public final class SpeechPlayer {

    public private(set) var isSpeaking = false
    /// Что сейчас произносится — экран подсвечивает активную кнопку.
    public private(set) var currentText: String?

    /// Скорость речи для обычного воспроизведения и для замедленного повтора.
    public static let normalRate: Float = 0.45
    public static let slowRate: Float = 0.3

    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SpeechDelegate()

    public init() {
        synthesizer.delegate = delegate
        delegate.onStart = { [weak self] text in
            self?.isSpeaking = true
            self?.currentText = text
        }
        delegate.onFinish = { [weak self] in
            self?.isSpeaking = false
            self?.currentText = nil
        }
    }

    /// Произносит фразу по-английски.
    /// - Parameter slow: замедленный темп — для повторного прослушивания.
    public func speak(_ text: String, slow: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Новая фраза прерывает предыдущую: иначе очередь копится
        // при быстрых нажатиях и голос отстаёт от экрана.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        configureAudioSession()

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.preferredVoice()
        utterance.rate = slow ? Self.slowRate : Self.normalRate
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.1

        delegate.pendingText = trimmed
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentText = nil
    }

    /// Лучший доступный английский голос. Улучшенные голоса пользователь
    /// может скачать в настройках системы — если их нет, берём стандартный.
    static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }

        // Порядок предпочтения: премиальные и улучшенные звучат заметно живее.
        if let premium = english.first(where: { $0.quality == .premium && $0.language == "en-US" }) {
            return premium
        }
        if let enhanced = english.first(where: { $0.quality == .enhanced && $0.language == "en-US" }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: "en-US") ?? english.first
    }

    /// Речь должна звучать даже в бесшумном режиме — иначе задание на слух
    /// молча «не работает», и причина неочевидна.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            // Не критично: без настройки сессии звук всё равно чаще всего играет.
        }
    }
}

/// Делегат вынесен в отдельный класс: AVSpeechSynthesizerDelegate требует NSObject,
/// а @Observable-класс им быть не может.
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var pendingText: String?
    var onStart: ((String) -> Void)?
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onStart?(utterance.speechString)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
