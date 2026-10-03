//
//  WordItem.swift
//  VoiceFilter_iOS
//
//  Model đại diện cho từ vựng thử thách từ words.json:
//  - Chứa id, word, phonetic, tip, level, subject, acceptedVariants, gameMode.
//

import Foundation

public struct WordItem: Identifiable, Codable, Hashable {
    public let id: String
    public let word: String
    public let phonetic: String
    public let tip: String
    public let level: DifficultyLevel
    public let subject: String
    public let acceptedVariants: [String]
    public let banner: String?
    public let gameMode: GameModeType?

    enum CodingKeys: String, CodingKey {
        case id
        case word
        case phonetic
        case tip
        case level
        case subject
        case acceptedVariants = "accepted_variants"
        case banner
        case gameMode = "game_mode"
    }

    public init(
        id: String = UUID().uuidString,
        word: String,
        phonetic: String = "",
        tip: String = "",
        level: DifficultyLevel = .basic,
        subject: String = "colors",
        acceptedVariants: [String] = [],
        banner: String? = nil,
        gameMode: GameModeType? = .voiceRunner
    ) {
        self.id = id
        self.word = word
        self.phonetic = phonetic
        self.tip = tip
        self.level = level
        self.subject = subject
        self.acceptedVariants = acceptedVariants
        self.banner = banner
        self.gameMode = gameMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.word = try container.decode(String.self, forKey: .word)
        self.phonetic = try container.decodeIfPresent(String.self, forKey: .phonetic) ?? ""
        self.tip = try container.decodeIfPresent(String.self, forKey: .tip) ?? ""
        self.level = try container.decodeIfPresent(DifficultyLevel.self, forKey: .level) ?? .basic
        self.subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? "colors"
        self.acceptedVariants = try container.decodeIfPresent([String].self, forKey: .acceptedVariants) ?? []
        self.banner = try container.decodeIfPresent(String.self, forKey: .banner)

        if let modeStr = try container.decodeIfPresent(String.self, forKey: .gameMode) {
            self.gameMode = GameModeType(rawValue: modeStr)
        } else {
            self.gameMode = .voiceRunner
        }
    }

    /// Trả về danh sách tất cả các biến thể hợp lệ (bao gồm chữ hoa/thường, rút gọn, biến thể)
    public func allMatchTargets() -> Set<String> {
        var targets = Set<String>()
        targets.insert(word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))

        for variant in acceptedVariants {
            let normalized = variant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            targets.insert(normalized)
            let bidirectional = WordItem.expandContractionsTwoWay(normalized)
            for item in bidirectional {
                targets.insert(item)
            }
        }

        let baseExpansions = WordItem.expandContractionsTwoWay(word)
        for item in baseExpansions {
            targets.insert(item)
        }

        return targets
    }

    public static func expandContractionsTwoWay(_ input: String) -> [String] {
        let lower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var results = [String]()

        let contractionMap: [(contraction: String, full: String)] = [
            ("can't", "cannot"),
            ("cant", "cannot"),
            ("won't", "will not"),
            ("wont", "will not"),
            ("i'm", "i am"),
            ("im", "i am"),
            ("it's", "it is"),
            ("its", "it is"),
            ("don't", "do not"),
            ("dont", "do not"),
            ("doesn't", "does not"),
            ("doesnt", "does not"),
            ("didn't", "did not"),
            ("didnt", "did not"),
            ("you're", "you are"),
            ("youre", "you are"),
            ("we're", "we are"),
            ("they're", "they are"),
            ("haven't", "have not"),
            ("hasn't", "has not"),
            ("let's", "let us")
        ]

        for pair in contractionMap {
            if lower == pair.contraction {
                results.append(pair.full)
            } else if lower == pair.full {
                results.append(pair.contraction)
            }
        }

        return results
    }
}
