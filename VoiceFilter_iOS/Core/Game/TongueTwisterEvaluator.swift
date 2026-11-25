//
//  TongueTwisterEvaluator.swift
//  VoiceFilter_iOS
//
//  Đánh giá và chấm điểm câu líu lưỡi (Tongue Twister):
//  - Highlight từng từ đã đọc khớp
//  - Độ chính xác (Accuracy %)
//  - Độ trôi chảy (Fluency %: phạt khi ngắt quá 1.5s giữa các từ)
//  - Xếp hạng 1-3 sao & phản hồi động
//

import Foundation

public final class TongueTwisterEvaluator {
    public static let maxAllowedPauseMs: Int64 = 1500 // Ngắt quá 1.5s bị trừ điểm trôi chảy

    public struct EvaluationResult {
        public let accuracyPercent: Float
        public let fluencyPercent: Float
        public let totalScore: Int
        public let stars: Int
        public let matchedWordIndices: Set<Int>
        public let feedback: String

        public init(
            accuracyPercent: Float,
            fluencyPercent: Float,
            totalScore: Int,
            stars: Int,
            matchedWordIndices: Set<Int>,
            feedback: String
        ) {
            self.accuracyPercent = accuracyPercent
            self.fluencyPercent = fluencyPercent
            self.totalScore = totalScore
            self.stars = stars
            self.matchedWordIndices = matchedWordIndices
            self.feedback = feedback
        }
    }

    public init() {}

    /// Tách câu thành danh sách từ chuẩn hóa
    public func tokenizeSentence(_ sentence: String) -> [String] {
        return sentence
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .map { token in
                token.lowercased().replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
            }
            .filter { !$0.isEmpty }
    }

    /// Tìm vị trí các từ trong câu đã được người dùng đọc khớp
    public func calculateMatchedIndices(targetTokens: [String], spokenTokens: [String]) -> Set<Int> {
        var matched = Set<Int>()
        var spokenIdx = 0

        for targetIdx in 0..<targetTokens.count {
            let target = targetTokens[targetIdx]
            while spokenIdx < spokenTokens.count {
                let spoken = spokenTokens[spokenIdx]
                spokenIdx += 1
                if spoken == target || target.contains(spoken) || spoken.contains(target) {
                    matched.insert(targetIdx)
                    break
                }
            }
        }
        return matched
    }

    /// Đánh giá toàn diện lượt đọc câu líu lưỡi
    public func evaluate(
        targetSentence: String,
        spokenText: String,
        pausesBetweenWordsMs: [Int64] = [],
        completionDurationSec: Float = 0
    ) -> EvaluationResult {
        let targetTokens = tokenizeSentence(targetSentence)
        let spokenTokens = tokenizeSentence(spokenText)

        if targetTokens.isEmpty {
            return EvaluationResult(accuracyPercent: 0, fluencyPercent: 0, totalScore: 0, stars: 1, matchedWordIndices: [], feedback: "Reference sentence is empty")
        }

        let matchedIndices = calculateMatchedIndices(targetTokens: targetTokens, spokenTokens: spokenTokens)
        let correctCount = matchedIndices.count
        let accuracyPercent = min(max(Float(correctCount) / Float(targetTokens.count), 0.0), 1.0)

        // Tính độ trôi chảy (Fluency)
        var longPausesCount = 0
        for pause in pausesBetweenWordsMs {
            if pause > TongueTwisterEvaluator.maxAllowedPauseMs {
                longPausesCount += 1
            }
        }
        let fluencyPercent = min(max(1.0 - (Float(longPausesCount) * 0.15), 0.0), 1.0)

        // Điểm số tổng hợp: 70% chính xác + 30% trôi chảy
        let rawScore = (accuracyPercent * 70.0) + (fluencyPercent * 30.0)
        let totalScore = min(max(Int(rawScore), 0), 100)

        let stars: Int
        switch totalScore {
        case 85...100: stars = 3
        case 65..<85: stars = 2
        default: stars = 1
        }

        let feedback: String
        switch stars {
        case 3: feedback = "Excellent! Fluent and very accurate!"
        case 2: feedback = "Good! Try to keep a smoother reading rhythm."
        default: feedback = "Keep trying! Slow down to pronounce each sound clearly."
        }

        return EvaluationResult(
            accuracyPercent: accuracyPercent,
            fluencyPercent: fluencyPercent,
            totalScore: totalScore,
            stars: stars,
            matchedWordIndices: matchedIndices,
            feedback: feedback
        )
    }
}
