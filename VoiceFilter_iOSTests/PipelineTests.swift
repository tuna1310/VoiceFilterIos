//
//  PipelineTests.swift
//  VoiceFilter_iOSTests
//
//  Kiểm thử các thành phần cốt lõi:
//  - Thuật toán so khớp phát âm 10 bước (PronunciationMatcher)
//  - State Machine & Event Timeline
//  - Quản lý từ vựng và Cache offline (VocabularyRepository)
//  - Cấu hình chia sẻ mạng xã hội (SocialShareManager)
//

import XCTest
@testable import VoiceFilter_iOS

final class PipelineTests: XCTestCase {

    func testExactMatch() {
        let matcher = PronunciationMatcher.shared
        let target = WordItem(
            id: "1",
            word: "apple",
            phonetic: "/ˈæp.əl/",
            tip: "Quả táo",
            subject: "daily_words",
            level: .basic,
            gameMode: .voiceRunner
        )

        let result = matcher.match(target: target, candidateSpoken: "apple", level: .basic)
        XCTAssertTrue(result.isMatched)
    }

    func testAcceptedVariantMatch() {
        let matcher = PronunciationMatcher.shared
        let target = WordItem(
            id: "2",
            word: "grey",
            phonetic: "/ɡreɪ/",
            tip: "Màu xám",
            subject: "colors",
            level: .basic,
            gameMode: .voiceRunner,
            acceptedVariants: ["gray"]
        )

        let result = matcher.match(target: target, candidateSpoken: "gray", level: .basic)
        XCTAssertTrue(result.isMatched)
    }

    func testMinimalPairBlockingOnAdvanced() {
        let matcher = PronunciationMatcher.shared
        let target = WordItem(
            id: "3",
            word: "ship",
            phonetic: "/ʃɪp/",
            tip: "Con tàu",
            subject: "vehicles",
            level: .advanced,
            gameMode: .voiceRunner
        )

        // Cấp độ Advanced phải chặn âm /i:/ vs /ɪ/ (sheep vs ship)
        let resultAdv = matcher.match(target: target, candidateSpoken: "sheep", level: .advanced)
        XCTAssertFalse(resultAdv.isMatched)

        // Cấp độ Basic được nới lỏng
        let resultBasic = matcher.match(target: target, candidateSpoken: "sheep", level: .basic)
        XCTAssertTrue(resultBasic.isMatched)
    }

    func testGameStateMachineTimelineRecording() {
        let sm = GameStateMachine()
        let words = [
            WordItem(id: "w1", word: "cat", phonetic: "/kæt/", tip: "Con mèo", subject: "animals", level: .basic, gameMode: .voiceRunner),
            WordItem(id: "w2", word: "dog", phonetic: "/dɒɡ/", tip: "Con chó", subject: "animals", level: .basic, gameMode: .voiceRunner)
        ]

        sm.start(words: words, durationSeconds: 30, timeLimitPerWordMs: 3000)
        sm.countdownTick(secondsRemaining: 0)

        if case .playing(let ps) = sm.state {
            XCTAssertEqual(ps.words.count, 2)
            XCTAssertEqual(ps.livesRemaining, 3)
        } else {
            XCTFail("State machine should be playing")
        }

        sm.wordMatched(spokenWord: "cat", pointsAwarded: 10)
        let events = sm.timeline.allEvents
        XCTAssertTrue(events.contains { $0.type == .gatePass })

        let currentRes = sm.buildCurrentResult()
        XCTAssertEqual(currentRes.finalScore, 10)
    }

    func testVocabularyRepositoryLoad() {
        let repo = VocabularyRepository.shared
        XCTAssertFalse(repo.allWords.isEmpty, "Kho từ vựng phải nạp thành công từ Bundle hoặc Cache.")
    }
}
