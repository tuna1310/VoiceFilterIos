//
//  GameStateMachine.swift
//  VoiceFilter_iOS
//
//  State Machine quản lý toàn bộ vòng đời trận đấu Voice Runner / Challenge:
//  - Quản lý 3 tim (livesRemaining)
//  - Tính điểm cộng dồn (+10đ, bonus combo streak)
//  - Gate progress di chuyển từ 0.0 -> 1.0 (linh vật) -> 1.5 (lướt qua sau lưng)
//  - Đếm ngược từng từ (wordTimeLimitMs) và tổng thời gian trận đấu
//  - Ghi timeline sự kiện đồng bộ SFX và phân tích
//

import Foundation
import Combine

public enum TimelineEventType: String, Codable {
    case gameStart = "GAME_START"
    case gateSpawn = "GATE_SPAWN"
    case gatePass = "GATE_PASS"
    case gateCrash = "GATE_CRASH"
    case wordTimeout = "WORD_TIMEOUT"
    case gameOver = "GAME_OVER"
}

public struct GameTimelineEvent: Identifiable, Codable {
    public let id = UUID()
    public let type: TimelineEventType
    public let timestampMs: Int64
    public let payload: String

    public init(type: TimelineEventType, timestampMs: Int64, payload: String = "") {
        self.type = type
        self.timestampMs = timestampMs
        self.payload = payload
    }
}

public final class GameEventTimeline {
    private var events: [GameTimelineEvent] = []

    public init() {}

    public func record(type: TimelineEventType, timestampMs: Int64, payload: String = "") {
        events.append(GameTimelineEvent(type: type, timestampMs: timestampMs, payload: payload))
    }

    public func clear() {
        events.removeAll()
    }

    public var allEvents: [GameTimelineEvent] {
        return events
    }
}

public enum FinishReason: String, Codable {
    case completed = "COMPLETED"
    case livesDepleted = "LIVES_DEPLETED"
    case timeOut = "TIME_OUT"
    case userQuit = "USER_QUIT"
}

public struct GameResult: Codable, Equatable {
    public let finalScore: Int
    public let wordsCompleted: Int
    public let totalWords: Int
    public let accuracyPercent: Float
    public let maxCombo: Int
    public let reason: FinishReason
    public let stars: Int
    public let timeElapsedSeconds: Float

    public init(
        finalScore: Int,
        wordsCompleted: Int,
        totalWords: Int,
        accuracyPercent: Float,
        maxCombo: Int,
        reason: FinishReason,
        stars: Int,
        timeElapsedSeconds: Float
    ) {
        self.finalScore = finalScore
        self.wordsCompleted = wordsCompleted
        self.totalWords = totalWords
        self.accuracyPercent = accuracyPercent
        self.maxCombo = maxCombo
        self.reason = reason
        self.stars = stars
        self.timeElapsedSeconds = timeElapsedSeconds
    }
}

public struct PlayingState: Equatable {
    public var words: [WordItem]
    public var currentWordIndex: Int
    public var livesRemaining: Int
    public var maxLives: Int
    public var score: Int
    public var combo: Int
    public var maxCombo: Int
    public var elapsedSeconds: Float
    public var maxDurationSeconds: Int
    public var wordElapsedMs: Int64
    public var wordTimeLimitMs: Int64
    public var gateProgress: Float // 0.0 (xa) -> 1.0 (tại linh vật) -> 1.5 (sau lưng)
    public var isGateSuccess: Bool? // nil: approaching, true: pass, false: crash
    public var consecutiveCorrect: Int
    public var isGateTransitioning: Bool

    public var currentWord: WordItem? {
        guard currentWordIndex >= 0 && currentWordIndex < words.count else { return nil }
        return words[currentWordIndex]
    }

    public var nextWord: WordItem? {
        let nextIdx = currentWordIndex + 1
        guard nextIdx < words.count else { return nil }
        return words[nextIdx]
    }
}

public enum GameState: Equatable {
    case idle
    case countdown(secondsRemaining: Int)
    case playing(state: PlayingState)
    case paused(state: PlayingState)
    case finished(result: GameResult)
}

public final class GameStateMachine: ObservableObject {
    @Published public private(set) var state: GameState = .idle
    public let timeline = GameEventTimeline()

    private let gateTransitionDurationMs: Int64 = 350
    private var transitionTimerMs: Int64 = 0
    private var initialWords: [WordItem] = []
    private var initialDuration: Int = 60
    private var initialTimeLimitPerWord: Int64 = 3000

    public init() {}

    public func start(words: [WordItem], durationSeconds: Int = 60, timeLimitPerWordMs: Int64 = 3000) {
        guard !words.isEmpty else { return }
        self.initialWords = words
        self.initialDuration = durationSeconds
        self.initialTimeLimitPerWord = timeLimitPerWordMs
        timeline.clear()

        state = .countdown(secondsRemaining: 3)
    }

    public func countdownTick(secondsRemaining: Int) {
        if case .countdown = state {
            if secondsRemaining > 0 {
                state = .countdown(secondsRemaining: secondsRemaining)
            } else {
                startPlaying()
            }
        }
    }

    private func startPlaying() {
        let initialPlaying = PlayingState(
            words: initialWords,
            currentWordIndex: 0,
            livesRemaining: 3,
            maxLives: 3,
            score: 0,
            combo: 0,
            maxCombo: 0,
            elapsedSeconds: 0,
            maxDurationSeconds: initialDuration,
            wordElapsedMs: 0,
            wordTimeLimitMs: initialTimeLimitPerWord,
            gateProgress: 0.0,
            isGateSuccess: nil,
            consecutiveCorrect: 0,
            isGateTransitioning: false
        )
        state = .playing(state: initialPlaying)
        timeline.record(type: .gameStart, timestampMs: 0)
        timeline.record(type: .gateSpawn, timestampMs: 0, payload: initialPlaying.currentWord?.word ?? "")
    }

    public func tick(deltaMs: Int64) {
        guard case .playing(var ps) = state else { return }

        // 1. Cập nhật thời gian tổng
        ps.elapsedSeconds += Float(deltaMs) / 1000.0
        let currentTotalMs = Int64(ps.elapsedSeconds * 1000)

        if ps.elapsedSeconds >= Float(ps.maxDurationSeconds) {
            finishGame(ps: ps, reason: .timeOut)
            return
        }

        // 2. Nếu đang trong hiệu ứng vượt cổng thành công hoặc đâm cổng (transition)
        if ps.isGateTransitioning {
            transitionTimerMs += deltaMs
            // Cổng tiếp tục lướt qua sau lưng từ 1.0 -> 1.5
            let progressExtra = Float(transitionTimerMs) / Float(gateTransitionDurationMs) * 0.5
            ps.gateProgress = min(1.0 + progressExtra, 1.5)

            if transitionTimerMs >= gateTransitionDurationMs {
                // Chuyển sang từ tiếp theo
                transitionTimerMs = 0
                ps.isGateTransitioning = false
                ps.isGateSuccess = nil
                ps.gateProgress = 0.0
                ps.wordElapsedMs = 0
                ps.currentWordIndex += 1

                if ps.currentWordIndex >= ps.words.count {
                    finishGame(ps: ps, reason: .completed)
                    return
                } else {
                    timeline.record(type: .gateSpawn, timestampMs: currentTotalMs, payload: ps.currentWord?.word ?? "")
                }
            }
            state = .playing(state: ps)
            return
        }

        // 3. Tiến trình cổng tiếp cận nhân vật: 0.0 -> 1.0
        ps.wordElapsedMs += deltaMs
        let progress = min(Float(ps.wordElapsedMs) / Float(ps.wordTimeLimitMs), 1.0)
        ps.gateProgress = progress

        // 4. Nếu hết thời gian của từ mà chưa đọc được -> Tính là Va chạm (Timeout / Crash)
        if ps.wordElapsedMs >= ps.wordTimeLimitMs {
            handleWordWrongOrTimeout(ps: &ps, reason: "Word timed out")
            return
        }

        state = .playing(state: ps)
    }

    public func wordMatched(spokenWord: String, pointsAwarded: Int = 10) {
        guard case .playing(var ps) = state, !ps.isGateTransitioning else { return }

        let currentTotalMs = Int64(ps.elapsedSeconds * 1000)
        ps.combo += 1
        ps.maxCombo = max(ps.maxCombo, ps.combo)
        ps.consecutiveCorrect += 1

        // Điểm combo bonus: combo >= 5 (+10), combo >= 3 (+5)
        let comboBonus = ps.combo >= 5 ? 10 : (ps.combo >= 3 ? 5 : 0)
        ps.score += pointsAwarded + comboBonus

        ps.isGateSuccess = true
        ps.isGateTransitioning = true
        transitionTimerMs = 0

        timeline.record(type: .gatePass, timestampMs: currentTotalMs, payload: "\(ps.currentWord?.word ?? "") (Combo: \(ps.combo))")
        state = .playing(state: ps)
    }

    public func wordWrong(reason: String) {
        guard case .playing(var ps) = state, !ps.isGateTransitioning else { return }
        handleWordWrongOrTimeout(ps: &ps, reason: reason)
    }

    private func handleWordWrongOrTimeout(ps: inout PlayingState, reason: String) {
        let currentTotalMs = Int64(ps.elapsedSeconds * 1000)
        ps.combo = 0
        ps.livesRemaining -= 1
        ps.isGateSuccess = false
        ps.isGateTransitioning = true
        transitionTimerMs = 0

        timeline.record(type: .gateCrash, timestampMs: currentTotalMs, payload: "\(ps.currentWord?.word ?? "") - \(reason)")

        if ps.livesRemaining <= 0 {
            finishGame(ps: ps, reason: .livesDepleted)
            return
        }

        state = .playing(state: ps)
    }

    public func pause() {
        if case .playing(let ps) = state {
            state = .paused(state: ps)
        }
    }

    public func resume() {
        if case .paused(let ps) = state {
            state = .playing(state: ps)
        }
    }

    public func restart() {
        start(words: initialWords, durationSeconds: initialDuration, timeLimitPerWordMs: initialTimeLimitPerWord)
    }

    private func finishGame(ps: PlayingState, reason: FinishReason) {
        let completed = ps.currentWordIndex
        let total = ps.words.count
        let accuracy = total > 0 ? (Float(completed) / Float(total)) * 100.0 : 0.0

        let stars: Int
        if ps.score >= 100 || (total > 0 && completed >= total) {
            stars = 3
        } else if ps.score >= 50 || completed >= 5 {
            stars = 2
        } else {
            stars = 1
        }

        let result = GameResult(
            finalScore: ps.score,
            wordsCompleted: completed,
            totalWords: total,
            accuracyPercent: accuracy,
            maxCombo: ps.maxCombo,
            reason: reason,
            stars: stars,
            timeElapsedSeconds: ps.elapsedSeconds
        )

        timeline.record(type: .gameOver, timestampMs: Int64(ps.elapsedSeconds * 1000), payload: "Score: \(ps.score)")
        state = .finished(result: result)
    }

    /// Trích xuất kết quả hiện tại kể cả khi trận đấu dừng sớm
    public func buildCurrentResult() -> GameResult {
        if case .finished(let res) = state {
            return res
        }
        if case .playing(let ps) = state {
            let completed = ps.currentWordIndex
            let total = ps.words.count
            let accuracy = total > 0 ? (Float(completed) / Float(total)) * 100.0 : 0.0
            let stars = ps.score >= 100 ? 3 : (ps.score >= 50 ? 2 : 1)
            return GameResult(
                finalScore: ps.score,
                wordsCompleted: completed,
                totalWords: total,
                accuracyPercent: accuracy,
                maxCombo: ps.maxCombo,
                reason: .userQuit,
                stars: stars,
                timeElapsedSeconds: ps.elapsedSeconds
            )
        }
        return GameResult(
            finalScore: 0,
            wordsCompleted: 0,
            totalWords: initialWords.count,
            accuracyPercent: 0,
            maxCombo: 0,
            reason: .userQuit,
            stars: 1,
            timeElapsedSeconds: 0
        )
    }
}
