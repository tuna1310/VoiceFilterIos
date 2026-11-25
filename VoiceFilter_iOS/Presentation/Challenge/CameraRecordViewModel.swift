//
//  CameraRecordViewModel.swift
//  VoiceFilter_iOS
//
//  ViewModel điều phối toàn bộ Pipeline Game AR Thử Thách:
//  - Camera, SpeechRecognizer, VideoRecorder
//  - GameStateMachine (Voice Runner, Tongue Twister, Category Rush)
//  - PronunciationMatcher, TongueTwisterEvaluator, CategoryRushEvaluator
//  - SoundEffectManager (SFX ding/buzz/crash và looping BGM)
//  - VideoCompositor: Tự động ghép Watermark, HUD và hòa âm SFX/BGM vào file MP4
//  - Haptic feedback & Visual feedback (Shake khi sai, Glow khi đúng)
//

import Foundation
import SwiftUI
import AVFoundation
import UIKit

public final class CameraRecordViewModel: ObservableObject, SpeechRecognizerDelegate {
    @Published public var isSessionReady = false
    @Published public var isRecording = false
    @Published public var recordingDuration: TimeInterval = 0.0
    @Published public var liveSpeechTranscript: String = ""
    @Published public var recordedVideoURL: URL?
    @Published public var showVideoPreview = false
    @Published public var errorMessage: String?
    @Published public var isSavingToPhotos = false
    @Published public var saveSuccessMessage: String?
    @Published public var currentCameraPosition: AVCaptureDevice.Position = .front
    @Published public var isOnDeviceSpeech: Bool = false

    // Video Compositing Pipeline
    @Published public var isCompositingVideo: Bool = false
    @Published public var compositingStatusText: String = ""

    // Visual & Haptic Feedback
    @Published public var triggerErrorShake: Bool = false

    // Game State & Canvas bindings
    @Published public var gameState: GameState = .idle
    @Published public var showConfetti: Bool = false
    @Published public var plusPointsBanner: String? = nil
    @Published public var tongueTwisterResult: TongueTwisterEvaluator.EvaluationResult?
    @Published public var categoryRushScore: Int = 0

    public let cameraManager = CameraManager()
    public let speechRecognizer = AppleSpeechRecognizer()
    public let videoRecorder = VideoRecorder(width: 1080, height: 1920)
    public let stateMachine = GameStateMachine()

    private let matcher = PronunciationMatcher.shared
    private let soundManager = SoundEffectManager.shared
    private let settings = SettingsRepository.shared

    private var tongueTwisterEvaluator: TongueTwisterEvaluator?
    private var categoryRushEvaluator: CategoryRushEvaluator?

    public var currentSubject: Subject = .colors
    public var currentDifficulty: DifficultyLevel = .basic
    public var currentGameMode: GameModeType = .voiceRunner
    public private(set) var currentWords: [WordItem] = []
    public private(set) var lastGameResult: GameResult? = nil

    private var gameLoopTimer: Timer?
    private var durationTimer: Timer?
    private var confettiTimer: Timer?
    private var shakeTimer: Timer?
    private var lastTickTime: TimeInterval = 0
    private var lastGateSuccess: Bool? = nil

    private let hapticNotification = UINotificationFeedbackGenerator()
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)

    public init() {
        setupPipeline()
    }

    deinit {
        stopAll()
    }

    private func setupPipeline() {
        speechRecognizer.delegate = self
        cameraManager.speechRecognizer = speechRecognizer
        cameraManager.videoRecorder = videoRecorder

        cameraManager.setupSession { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.cameraManager.startSession()
                    self.isSessionReady = true
                    self.isOnDeviceSpeech = self.speechRecognizer.isOnDevice
                case .failure(let error):
                    self.errorMessage = "Couldn't start camera: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Khởi động ván chơi mới theo chủ đề, độ khó và chế độ
    public func startGame(
        subject: Subject,
        difficulty: DifficultyLevel,
        gameMode: GameModeType,
        words: [WordItem]
    ) {
        self.currentSubject = subject
        self.currentDifficulty = difficulty
        self.currentGameMode = gameMode
        self.currentWords = words
        self.lastGameResult = nil
        self.lastGateSuccess = nil

        if gameMode == .tongueTwister {
            self.tongueTwisterEvaluator = TongueTwisterEvaluator()
        } else if gameMode == .categoryRush {
            let allowed = words.map { $0.word }
            self.categoryRushEvaluator = CategoryRushEvaluator(allowedSubjectWords: allowed)
        }

        // Bắt đầu đếm ngược 3s trong State Machine
        let timePerWord = difficulty.timeLimitPerWordMs
        let duration = gameMode.defaultDurationSeconds
        stateMachine.start(words: words, durationSeconds: duration, timeLimitPerWordMs: timePerWord)
        self.gameState = stateMachine.state

        // Timer đếm ngược 3-2-1
        var cd = 3
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            cd -= 1
            if cd > 0 {
                self.stateMachine.countdownTick(secondsRemaining: cd)
                self.gameState = self.stateMachine.state
            } else {
                timer.invalidate()
                self.stateMachine.countdownTick(secondsRemaining: 0)
                self.gameState = self.stateMachine.state
                self.startActiveGameSession()
            }
        }
    }

    private func startActiveGameSession() {
        do {
            try speechRecognizer.startTurn()
            self.isOnDeviceSpeech = speechRecognizer.isOnDevice

            _ = try videoRecorder.startRecording()
            self.isRecording = true
            self.recordingDuration = 0.0

            soundManager.startBGM()

            // Game loop timer 60 FPS
            lastTickTime = CACurrentMediaTime()
            gameLoopTimer?.invalidate()
            gameLoopTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let now = CACurrentMediaTime()
                let deltaMs = Int64((now - self.lastTickTime) * 1000)
                self.lastTickTime = now

                self.stateMachine.tick(deltaMs: max(deltaMs, 16))
                self.gameState = self.stateMachine.state

                // Kiểm tra sự kiện cổng đúng/sai để kích hoạt Haptic & Visual Shake
                if case .playing(let ps) = self.gameState {
                    if ps.isGateSuccess == false && self.lastGateSuccess != false {
                        self.triggerErrorFeedback()
                    }
                    self.lastGateSuccess = ps.isGateSuccess
                }

                // Kiểm tra kết thúc game
                if case .finished(let result) = self.gameState {
                    self.handleGameFinish(result: result)
                }
            }

            // Đo thời lượng ghi
            durationTimer?.invalidate()
            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingDuration += 0.1
            }

        } catch {
            errorMessage = "Failed to start the round: \(error.localizedDescription)"
            stopAll()
        }
    }

    // MARK: - SpeechRecognizerDelegate
    // MARK: - SpeechRecognizerDelegate
    public func speechRecognizer(_ recognizer: SpeechRecognizerProtocol, didRecognizePartialText text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.liveSpeechTranscript = text
            self.evaluateLiveSpeech(text)
        }
    }

    public func speechRecognizer(_ recognizer: SpeechRecognizerProtocol, didRecognizeFinalText text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.liveSpeechTranscript = text
            self.evaluateLiveSpeech(text)
        }
    }

    public func speechRecognizer(_ recognizer: SpeechRecognizerProtocol, didEncounterError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "Recognition error: \(error.localizedDescription)"
        }
    }

    public func speechRecognizerDidDetectSilenceTimeout(_ recognizer: SpeechRecognizerProtocol) {
        // Im lặng quá ngưỡng, có thể thử lại nếu cần
    }

    public func speechRecognizer(_ recognizer: SpeechRecognizerProtocol, didChangeAvailability available: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isOnDeviceSpeech = recognizer.isOnDevice
        }
    }

    public func speechRecognizerDidReceivePartial(transcript: String) {
        speechRecognizer(speechRecognizer, didRecognizePartialText: transcript)
    }

    public func speechRecognizerDidReceiveFinal(transcript: String) {
        speechRecognizer(speechRecognizer, didRecognizeFinalText: transcript)
    }

    public func speechRecognizerDidFail(error: Error) {
        speechRecognizer(speechRecognizer, didEncounterError: error)
    }

    public func speechRecognizerStatusDidChange(isOnDevice: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isOnDeviceSpeech = isOnDevice
        }
    }

    /// Đánh giá từ ngữ thời gian thực theo từng chế độ chơi
    private func evaluateLiveSpeech(_ spoken: String) {
        guard case .playing(let ps) = gameState, !ps.isGateTransitioning else { return }

        switch currentGameMode {
        case .voiceRunner:
            guard let currentWord = ps.currentWord else { return }
            let result = matcher.match(target: currentWord, candidateSpoken: spoken, level: currentDifficulty)
            if result.isMatched {
                triggerSuccessCelebration(points: 10)
                stateMachine.wordMatched(spokenWord: spoken, pointsAwarded: 10)
                gameState = stateMachine.state
            }

        case .tongueTwister:
            guard let currentWord = ps.currentWord, let evaluator = tongueTwisterEvaluator else { return }
            let eval = evaluator.evaluate(targetSentence: currentWord.word, spokenText: spoken)
            self.tongueTwisterResult = eval
            if eval.accuracyPercent >= 0.85 {
                triggerSuccessCelebration(points: 30)
                stateMachine.wordMatched(spokenWord: spoken, pointsAwarded: 30)
                gameState = stateMachine.state
            }

        case .categoryRush:
            guard let evaluator = categoryRushEvaluator else { return }
            let subResult = evaluator.submitWord(spoken)
            if case .accepted = subResult {
                triggerSuccessCelebration(points: 10)
                self.categoryRushScore = evaluator.getScore()
                soundManager.playSuccess()
            }
        }
    }

    private func triggerSuccessCelebration(points: Int) {
        soundManager.playSuccess()
        hapticNotification.notificationOccurred(.success)
        showConfetti = true
        plusPointsBanner = "+\(points) pts"

        confettiTimer?.invalidate()
        confettiTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.showConfetti = false
            self?.plusPointsBanner = nil
        }
    }

    private func triggerErrorFeedback() {
        soundManager.playError()
        hapticNotification.notificationOccurred(.error)
        triggerErrorShake = true

        shakeTimer?.invalidate()
        shakeTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            self?.triggerErrorShake = false
        }
    }

    private func handleGameFinish(result: GameResult) {
        gameLoopTimer?.invalidate()
        gameLoopTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil

        self.lastGameResult = result
        soundManager.stopBGM()
        if result.livesRemainingLost() {
            soundManager.playCrash()
        }

        settings.updateHighScore(score: result.finalScore)

        stopRecording()
    }

    public func pauseGame() {
        stateMachine.pause()
        gameState = stateMachine.state
        soundManager.pauseBGM()
    }

    public func resumeGame() {
        stateMachine.resume()
        gameState = stateMachine.state
        lastTickTime = CACurrentMediaTime()
        soundManager.startBGM()
    }

    public func stopRecording() {
        guard isRecording else { return }

        speechRecognizer.stopTurn()
        soundManager.stopBGM()

        videoRecorder.stopRecording { [weak self] result in
            guard let self = self else { return }
            self.isRecording = false
            switch result {
            case .success(let rawURL):
                self.compositeRecordedVideo(rawURL: rawURL)
            case .failure(let error):
                self.errorMessage = "Video export error: \(error.localizedDescription)"
            }
        }
    }

    /// Tự động ghép Watermark bản quyền, đồ họa game và hòa âm SFX/BGM vào file MP4 cuối cùng
    private func compositeRecordedVideo(rawURL: URL) {
        let gameResult = self.lastGameResult ?? self.stateMachine.buildCurrentResult()
        self.lastGameResult = gameResult

        self.isCompositingVideo = true
        self.compositingStatusText = "Rendering TikTok video (watermark & effects)..."

        VideoCompositor.shared.compositeVideo(
            rawVideoURL: rawURL,
            timelineEvents: self.stateMachine.timeline.allEvents,
            words: self.currentWords,
            gameResult: gameResult
        ) { [weak self] compResult in
            guard let self = self else { return }
            self.isCompositingVideo = false
            switch compResult {
            case .success(let compositedURL):
                print("[CameraRecordViewModel] Video composited successfully: \(compositedURL.path)")
                self.recordedVideoURL = compositedURL
                self.showVideoPreview = true
            case .failure(let error):
                print("[CameraRecordViewModel] Video compositing warning: \(error.localizedDescription), using raw video")
                self.recordedVideoURL = rawURL
                self.showVideoPreview = true
            }
        }
    }

    public func switchCamera() {
        cameraManager.switchCamera()
        currentCameraPosition = cameraManager.currentCameraPosition
    }

    public func saveToPhotosAlbum() {
        guard let url = recordedVideoURL else { return }
        isSavingToPhotos = true
        PhotoLibraryExporter.shared.saveVideoToAlbum(fileURL: url) { [weak self] result in
            guard let self = self else { return }
            self.isSavingToPhotos = false
            switch result {
            case .success:
                self.saveSuccessMessage = "Video saved to Photo Library!"
            case .failure(let error):
                self.errorMessage = "Failed to save video: \(error.localizedDescription)"
            }
        }
    }

    public func stopAll() {
        gameLoopTimer?.invalidate()
        gameLoopTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        confettiTimer?.invalidate()
        confettiTimer = nil
        shakeTimer?.invalidate()
        shakeTimer = nil

        speechRecognizer.stopTurn()
        soundManager.stopBGM()
        cameraManager.stopSession()
    }
}

extension GameResult {
    func livesRemainingLost() -> Bool {
        return self.reason == .livesDepleted
    }
}
