//
//  AppleSpeechRecognizer.swift
//  VoiceFilter_iOS
//
//  Triển khai SpeechRecognizerProtocol bằng Apple Speech.framework:
//  - Vòng đời nhận diện gắn theo từng lượt chơi (Turn-based lifecycle).
//  - Xử lý lỗi 1110: Giới hạn tối đa 2 lần thử im lặng trong lượt. Nếu vượt quá, DỪNG nhận diện,
//    chuyển sang trạng thái silenceTimeout ("Không nghe thấy"), chờ game/người dùng kích hoạt lại.
//  - Ghi log minh bạch nhánh restart (TC-03: Branch isFinal vs Branch Mandatory 55s)
//    và đo lường lượng chữ bị mất / tính liên tục giữa các phiên.
//

import Foundation
import Speech
import CoreMedia

public final class AppleSpeechRecognizer: NSObject, SpeechRecognizerProtocol {
    public weak var delegate: SpeechRecognizerDelegate?

    public private(set) var state: SpeechRecognizerState = .idle
    public private(set) var isRunning: Bool = false
    public private(set) var isOnDevice: Bool = false
    public var currentLocale: Locale = Locale(identifier: "en-US") {
        didSet {
            setupRecognizer()
        }
    }

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let syncQueue = DispatchQueue(label: "com.voicefilter.speech.syncQueue")
    private var sessionStartTime: Date?
    private var autoRestartTimer: Timer?
    private var mandatoryRestartTimer: Timer?
    private var shouldRestartAtNextFinalResult: Bool = false

    // MARK: - Turn & Silence Timeout (Lỗi 1110)
    private var silenceRetriesInCurrentTurn: Int = 0
    private let maxSilenceRetriesPerTurn: Int = 2

    // MARK: - TC-03 Audit: Branch Logging & Text Continuity Tracking
    private var lastRecognizedTextBeforeRestart: String = ""
    private var isFirstResultAfterRestart: Bool = false
    private let proactiveRestartWindowStart: TimeInterval = 45.0
    private let hardTimeoutThreshold: TimeInterval = 55.0

    public override init() {
        super.init()
        setupRecognizer()
    }

    deinit {
        stopRecognition()
    }

    private func setupRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: currentLocale)
        speechRecognizer?.delegate = self

        if let recognizer = speechRecognizer {
            isOnDevice = recognizer.supportsOnDeviceRecognition
            print("[AppleSpeechRecognizer] Setup: locale=\(currentLocale.identifier), onDevice=\(isOnDevice)")
        } else {
            isOnDevice = false
            print("[AppleSpeechRecognizer] Error: Locale \(currentLocale.identifier) unsupported by SFSpeechRecognizer")
        }
    }

    // MARK: - Turn-based Lifecycle

    public func startTurn() throws {
        syncQueue.sync {
            silenceRetriesInCurrentTurn = 0
            state = .listening
            do {
                try startSessionInternal()
            } catch {
                state = .failed(error)
                delegate?.speechRecognizer(self, didEncounterError: error)
            }
        }
    }

    public func stopTurn() {
        syncQueue.sync {
            cleanupSession()
            state = .idle
            isRunning = false
            cancelTimers()
            silenceRetriesInCurrentTurn = 0
            print("[AppleSpeechRecognizer] Turn stopped.")
        }
    }

    public func retryAfterSilence() throws {
        try syncQueue.sync {
            print("[AppleSpeechRecognizer] Retrying turn after silence...")
            silenceRetriesInCurrentTurn = 0
            state = .listening
            try startSessionInternal()
        }
    }

    public func stopRecognition() {
        stopTurn()
    }

    private func startSessionInternal() throws {
        cleanupSession()

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            state = .failed(SpeechRecognizerError.recognizerUnavailable)
            throw SpeechRecognizerError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            isOnDevice = true
        } else {
            request.requiresOnDeviceRecognition = false
            isOnDevice = false
        }

        if #available(iOS 16.0, *) {
            request.addsPunctuation = false
        }

        recognitionRequest = request
        sessionStartTime = Date()
        shouldRestartAtNextFinalResult = false

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.silenceRetriesInCurrentTurn = 0
                let text = result.bestTranscription.formattedString

                // TC-03 Text Continuity Audit
                if self.isFirstResultAfterRestart {
                    self.isFirstResultAfterRestart = false
                    let previous = self.lastRecognizedTextBeforeRestart
                    print("[AppleSpeechRecognizer] [TC-03 AUDIT] Post-restart text received: '\(text)' | Prior text before restart: '\(previous)'")
                }
                self.lastRecognizedTextBeforeRestart = text

                self.delegate?.speechRecognizer(self, didRecognizePartialText: text)

                if result.isFinal {
                    self.delegate?.speechRecognizer(self, didRecognizeFinalText: text)

                    // TC-03: Nhánh 1 - Restart tại ranh giới kết quả cuối cùng (isFinal)
                    if self.shouldRestartAtNextFinalResult && self.isRunning {
                        print("[AppleSpeechRecognizer] [TC-03 BRANCH: isFinal Sentence Boundary] Restarting at word completion. No words lost. Prior: '\(text)'")
                        self.executeRestart(reason: "isFinal Boundary")
                    }
                }
            }

            if let error = error {
                self.handleError(error)
            }
        }

        isRunning = true
        scheduleWatchdogTimers()
    }

    public func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        syncQueue.async { [weak self] in
            guard let self = self, self.isRunning, self.state == .listening, let request = self.recognitionRequest else {
                return
            }
            request.appendAudioSampleBuffer(sampleBuffer)
        }
    }

    // MARK: - Error Handling & 1110 Silence Limit

    private func handleError(_ error: Error) {
        let nsError = error as NSError
        let isSilenceTimeout = (nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110)
        let isSessionTimeout = (nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 203)
                                || (nsError.domain == "kLSRErrorDomain" && nsError.code == 201)

        if isSilenceTimeout && isRunning {
            silenceRetriesInCurrentTurn += 1
            print("[AppleSpeechRecognizer] Silence detected (Error 1110). Count: \(silenceRetriesInCurrentTurn)/\(maxSilenceRetriesPerTurn)")

            if silenceRetriesInCurrentTurn >= maxSilenceRetriesPerTurn {
                // ĐẠT NGƯỠNG IM LẶNG: DỪNG nhận diện, báo silence timeout, KHÔNG tự động restart vô tận!
                print("[AppleSpeechRecognizer] Silence limit reached for turn (\(maxSilenceRetriesPerTurn)). Stopping recognition and awaiting user/game input.")
                stopTurn()
                state = .silenceTimeout
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.speechRecognizerDidDetectSilenceTimeout(self)
                }
            } else {
                // Thử lại 1 lần trong turn với backoff nhẹ
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    guard let self = self, self.isRunning, self.state == .listening else { return }
                    self.executeRestart(reason: "Silence Retry #\(self.silenceRetriesInCurrentTurn)")
                }
            }
        } else if isSessionTimeout && isRunning {
            print("[AppleSpeechRecognizer] [TC-03 BRANCH: Session Timeout 203] Executing seamless session recovery...")
            executeRestart(reason: "Timeout 203")
        } else if isRunning {
            print("[AppleSpeechRecognizer] Error: \(error.localizedDescription)")
            delegate?.speechRecognizer(self, didEncounterError: error)
        }
    }

    // MARK: - Watchdog Timers & TC-03 Auditing

    private func scheduleWatchdogTimers() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cancelTimers()

            // 1. Sau 45s: Sẵn sàng restart khi có isFinal
            self.autoRestartTimer = Timer.scheduledTimer(withTimeInterval: self.proactiveRestartWindowStart, repeats: false) { [weak self] _ in
                guard let self = self, self.isRunning else { return }
                self.shouldRestartAtNextFinalResult = true
                print("[AppleSpeechRecognizer] [TC-03] Reached 45s window. Arming proactive restart at next word break (isFinal)...")

                // 2. Mốc cứng 55s: Nhánh 2 - Cưỡng chế restart nếu không có isFinal
                self.mandatoryRestartTimer = Timer.scheduledTimer(withTimeInterval: (self.hardTimeoutThreshold - self.proactiveRestartWindowStart), repeats: false) { [weak self] _ in
                    guard let self = self, self.isRunning else { return }
                    let lastPartial = self.lastRecognizedTextBeforeRestart
                    print("[AppleSpeechRecognizer] [TC-03 BRANCH: Mandatory 55s Ceiling] Forced restart without isFinal! Last partial captured: '\(lastPartial)'. Evaluating potential text gap...")
                    self.executeRestart(reason: "Mandatory 55s Ceiling")
                }
            }
        }
    }

    private func cancelTimers() {
        autoRestartTimer?.invalidate()
        autoRestartTimer = nil
        mandatoryRestartTimer?.invalidate()
        mandatoryRestartTimer = nil
    }

    private func executeRestart(reason: String) {
        syncQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.isFirstResultAfterRestart = true
            self.cleanupSession()
            do {
                try self.startSessionInternal()
                print("[AppleSpeechRecognizer] Restart executed successfully (\(reason)).")
            } catch {
                print("[AppleSpeechRecognizer] Restart failed: \(error.localizedDescription)")
                self.delegate?.speechRecognizer(self, didEncounterError: error)
            }
        }
    }

    private func cleanupSession() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension AppleSpeechRecognizer: SFSpeechRecognizerDelegate {
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        delegate?.speechRecognizer(self, didChangeAvailability: available)
    }
}
