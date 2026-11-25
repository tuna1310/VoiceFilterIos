//
//  PronunciationMatcher.swift
//  VoiceFilter_iOS
//
//  Bộ so khớp phát âm 10 bước chuẩn theo đặc tả kiến trúc:
//  - So khớp chính xác
//  - Accepted variants từ WordItem
//  - Chuẩn hóa viết tắt (Contractions)
//  - Bản đồ từ đồng âm (Homophones)
//  - Chặn cặp từ tối thiểu (Minimal pairs) ở cấp độ Khó
//  - Cặp âm gần giống (Near phonetic)
//  - Double Metaphone & Soundex
//  - Ngưỡng khoảng cách Levenshtein theo cấp độ
//

import Foundation

public struct MatchResult {
    public let isMatched: Bool
    public let reason: String
    public let score: Int

    public init(isMatched: Bool, reason: String, score: Int = 100) {
        self.isMatched = isMatched
        self.reason = reason
        self.score = isMatched ? score : 0
    }
}

public final class PronunciationMatcher {
    public static let shared = PronunciationMatcher()

    private let minimalPairRules: [String: [(word: String, level: DifficultyLevel)]] = [
        "ship": [("sheep", .advanced)],
        "sheep": [("ship", .advanced)],
        "fit": [("feet", .advanced)],
        "feet": [("fit", .advanced)],
        "pen": [("pan", .medium)],
        "pan": [("pen", .medium)],
        "bit": [("beat", .advanced)],
        "beat": [("bit", .advanced)],
        "sit": [("seat", .advanced)],
        "seat": [("sit", .advanced)],
        "live": [("leave", .advanced)],
        "leave": [("live", .advanced)]
    ]

    private let nearPhoneticPairs: [String: Set<String>] = [
        "ship": ["sheep"], "sheep": ["ship"],
        "fit": ["feet"], "feet": ["fit"],
        "bit": ["beat"], "beat": ["bit"],
        "sit": ["seat"], "seat": ["sit"],
        "live": ["leave"], "leave": ["live"]
    ]

    private let homophones: [String: Set<String>] = [
        "write": ["right"], "right": ["write"],
        "sun": ["son"], "son": ["sun"],
        "sea": ["see"], "see": ["sea"],
        "two": ["to", "too"], "to": ["two", "too"], "too": ["two", "to"],
        "their": ["there", "theyre"], "there": ["their", "theyre"], "theyre": ["their", "there"],
        "hear": ["here"], "here": ["hear"],
        "bare": ["bear"], "bear": ["bare"],
        "by": ["bye", "buy"], "bye": ["by", "buy"], "buy": ["by", "bye"],
        "flower": ["flour"], "flour": ["flower"],
        "knight": ["night"], "night": ["knight"],
        "know": ["no"], "no": ["know"],
        "mail": ["male"], "male": ["mail"],
        "meet": ["meat"], "meat": ["meet"],
        "pair": ["pear"], "pear": ["pair"],
        "peace": ["piece"], "piece": ["peace"],
        "plain": ["plane"], "plane": ["plain"],
        "rain": ["reign", "rein"], "reign": ["rain", "rein"], "rein": ["rain", "reign"],
        "road": ["rode"], "rode": ["road"],
        "some": ["sum"], "sum": ["some"],
        "steal": ["steel"], "steel": ["steal"],
        "tail": ["tale"], "tale": ["tail"],
        "weak": ["week"], "week": ["weak"],
        "which": ["witch"], "witch": ["which"],
        "whole": ["hole"], "hole": ["whole"],
        "wood": ["would"], "would": ["wood"]
    ]

    private let contractionGroups: [Set<String>] = [
        ["cant", "cannot", "can not"],
        ["dont", "do not"],
        ["wont", "will not"],
        ["its", "it is"],
        ["im", "i am"],
        ["ive", "i have"],
        ["ill", "i will"],
        ["id", "i would", "i had"],
        ["youre", "you are"],
        ["youve", "you have"],
        ["youll", "you will"],
        ["youd", "you would"],
        ["hes", "he is", "he has"],
        ["shes", "she is", "she has"],
        ["were", "we are"],
        ["weve", "we have"],
        ["well", "we will"],
        ["theyre", "they are"],
        ["theyve", "they have"],
        ["theyll", "they will"],
        ["thats", "that is"],
        ["theres", "there is"],
        ["whats", "what is"],
        ["lets", "let us"],
        ["isnt", "is not"],
        ["arent", "are not"],
        ["wasnt", "was not"],
        ["werent", "were not"],
        ["hasnt", "has not"],
        ["havent", "have not"],
        ["hadnt", "had not"],
        ["doesnt", "does not"],
        ["didnt", "did not"]
    ]

    public init() {}

    /// Chuẩn hóa chuỗi (chữ thường, xóa dấu câu và khoảng trắng dư)
    public func normalize(_ input: String) -> String {
        let lower = input.lowercased()
        let cleaned = lower.replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Đánh giá xem từ người dùng nói có khớp với từ mục tiêu hay không
    public func match(target: WordItem, candidateSpoken: String, level: DifficultyLevel) -> MatchResult {
        let normTarget = normalize(target.word)
        let normCandidate = normalize(candidateSpoken)

        if normTarget.isEmpty || normCandidate.isEmpty {
            return MatchResult(isMatched: false, reason: "Empty string")
        }

        // Bước 1: So khớp chính xác 100%
        if normTarget == normCandidate {
            return MatchResult(isMatched: true, reason: "Exact match")
        }

        // Bước 2: So khớp Accepted Variants
        let variants = target.acceptedVariants.map { normalize($0) }
        if variants.contains(normCandidate) {
            return MatchResult(isMatched: true, reason: "Accepted variant match")
        }

        // Bước 3: So khớp nhóm viết tắt (Contractions)
        for group in contractionGroups {
            if group.contains(normTarget) && group.contains(normCandidate) {
                return MatchResult(isMatched: true, reason: "Equivalent contraction match")
            }
        }

        // Bước 4: So khớp Từ đồng âm (Homophones)
        if let homos = homophones[normTarget], homos.contains(normCandidate) {
            return MatchResult(isMatched: true, reason: "Homophone match")
        }

        // Bước 5: Chặn cặp từ tối thiểu (Minimal Pair Check) ở cấp độ khó
        if let rules = minimalPairRules[normTarget] {
            for (ruleWord, ruleLevel) in rules {
                if normCandidate == ruleWord {
                    if (level == .advanced && ruleLevel == .advanced) || (level == .medium && ruleLevel == .medium) {
                        return MatchResult(isMatched: false, reason: "Blocked minimal-pair confusion (\(normTarget) vs \(ruleWord)) at level \(level.displayName)")
                    }
                }
            }
        }

        // Bước 6: Cặp âm gần giống (Near Phonetic) ở cấp độ Dễ/Vừa
        if level != .advanced {
            if let nearSet = nearPhoneticPairs[normTarget], nearSet.contains(normCandidate) {
                return MatchResult(isMatched: true, reason: "Approximate minimal-pair match at level \(level.displayName)")
            }
        }

        // Bước 7: Double Metaphone
        let targetMeta = DoubleMetaphone.encode(normTarget)
        let candMeta = DoubleMetaphone.encode(normCandidate)

        let metaMatch = (!targetMeta.primary.isEmpty && (
            targetMeta.primary == candMeta.primary ||
            targetMeta.primary == candMeta.secondary ||
            (!targetMeta.secondary.isEmpty && targetMeta.secondary == candMeta.primary)
        ))

        let levRatio = Levenshtein.similarityRatio(normTarget, normCandidate)

        if metaMatch {
            if level.requiresLevenshteinOnPhoneticMatch {
                if levRatio >= level.minimumLevenshteinThreshold {
                    return MatchResult(isMatched: true, reason: "Double Metaphone + Levenshtein match at \(Int(levRatio * 100))%")
                }
            } else {
                return MatchResult(isMatched: true, reason: "Double Metaphone phonetic match")
            }
        }

        // Bước 8: Soundex Match
        let targetSoundex = Soundex.encode(normTarget)
        let candSoundex = Soundex.encode(normCandidate)

        if !targetSoundex.isEmpty && targetSoundex == candSoundex {
            if level != .advanced || levRatio >= level.minimumLevenshteinThreshold {
                return MatchResult(isMatched: true, reason: "Soundex match (\(targetSoundex))")
            }
        }

        // Bước 9: Ngưỡng tương đồng Levenshtein
        if levRatio >= level.minimumLevenshteinThreshold {
            return MatchResult(isMatched: true, reason: "Levenshtein similarity \(Int(levRatio * 100))% (>= \(Int(level.minimumLevenshteinThreshold * 100))%)")
        }

        // Bước 10: Không đạt
        return MatchResult(isMatched: false, reason: "No match (similarity: \(Int(levRatio * 100))% < \(Int(level.minimumLevenshteinThreshold * 100))%)")
    }
}
