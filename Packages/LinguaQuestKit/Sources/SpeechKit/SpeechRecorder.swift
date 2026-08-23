import Foundation
import AVFoundation
import Speech
import Observation

/// Почему запись не началась — экран показывает это человеческим языком.
public enum SpeechRecorderError: LocalizedError, Equatable {
    case microphoneDenied
    case recognitionDenied
    case recognizerUnavailable
    case engineFailed(String)

    public var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Нет доступа к микрофону. Разрешите его в Настройках → LinguaQuest."
        case .recognitionDenied:
            return "Нет доступа к распознаванию речи. Разрешите его в Настройках → LinguaQuest."
        case .recognizerUnavailable:
            return "Распознавание английской речи сейчас недоступно на устройстве."
        case .engineFailed(let reason):
            return "Не удалось записать звук: \(reason)"
        }
    }
}

/// Запись голоса и распознавание английской речи.
///
/// Работает офлайн, если система скачала языковую модель; иначе Apple использует сервер.
/// Записанный звук нигде не сохраняется — распознанный текст живёт только в памяти
/// до конца задания.
@MainActor
@Observable
public final class SpeechRecorder {

    public private(set) var isRecording = false
    /// Текст, распознанный к текущему моменту, — показывается по мере говорения.
    public private(set) var transcript = ""
    public private(set) var error: SpeechRecorderError?
    /// Громкость входного сигнала 0...1 — для индикатора уровня.
    public private(set) var level: Double = 0

    /// Сколько секунд ждать перед автоостановкой: длинных фраз в A1 нет.
    public static let maxDuration: TimeInterval = 12

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var autoStopWork: DispatchWorkItem?

    public init() {}

    /// Запрашивает оба разрешения: микрофон и распознавание.
    /// Возвращает true, только если выданы оба.
    public func requestPermissions() async -> Bool {
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else {
            error = .recognitionDenied
            return false
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        if !micGranted { error = .microphoneDenied }
        return micGranted
    }

    public func start() async {
        guard !isRecording else { return }
        error = nil
        transcript = ""

        guard await requestPermissions() else { return }
        guard let recognizer, recognizer.isAvailable else {
            error = .recognizerUnavailable
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Учебные фразы короткие: держать точность важнее, чем экономить трафик,
            // но если модель скачана — распознаём на устройстве.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                let power = Self.averagePower(of: buffer)
                Task { @MainActor in self?.level = power }
            }

            engine.prepare()
            try engine.start()
            isRecording = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true {
                        self.finishRecording()
                    }
                }
            }

            scheduleAutoStop()
        } catch {
            self.error = .engineFailed(error.localizedDescription)
            finishRecording()
        }
    }

    /// Останавливает запись. Распознавание может дослать финальный результат следом.
    public func stop() {
        guard isRecording else { return }
        request?.endAudio()
        finishRecording()
    }

    private func finishRecording() {
        autoStopWork?.cancel()
        autoStopWork = nil

        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        task?.finish()
        task = nil
        request = nil
        isRecording = false
        level = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Страховка от забытой записи: без неё микрофон остался бы включён,
    /// если пользователь отвлёкся и не нажал «Стоп».
    private func scheduleAutoStop() {
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.stop() }
        }
        autoStopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maxDuration, execute: work)
    }

    /// Средняя громкость буфера, приведённая к 0...1.
    static func averagePower(of buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<count { sum += channel[i] * channel[i] }
        let rms = (sum / Float(count)).squareRoot()

        // Логарифмическая шкала: линейная почти не шевелится при обычной речи.
        // Считаем в Float (тип буфера), наружу отдаём Double.
        let decibels = 20 * log10(max(rms, 0.000_001))
        let normalized = min(1, max(0, (decibels + 50) / 50))
        return Double(normalized)
    }
}
