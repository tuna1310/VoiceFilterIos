//
//  DifficultyLevel.swift
//  VoiceFilter_iOS
//
//  3 Cấp độ thử thách: Basic (Beginner), Medium (Intermediate), Advanced (Expert).
//  Quy định: Thời gian mỗi từ, ngưỡng so khớp Levenshtein, và độ dài câu/từ vựng.
//

import Foundation

public enum DifficultyLevel: String, CaseIterable, Codable, Identifiable {
    case basic = "basic"
    case medium = "medium"
    case advanced = "advanced"

    public var id: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self).lowercased()
        switch raw {
        case "basic", "beginner", "easy":
            self = .basic
        case "medium", "intermediate":
            self = .medium
        case "advanced", "expert", "hard":
            self = .advanced
        default:
            self = .basic
        }
    }

    public var displayName: String {
        switch self {
        case .basic: return "Basic"
        case .medium: return "Medium"
        case .advanced: return "Advanced"
        }
    }

    public var englishDisplayName: String {
        switch self {
        case .basic: return "Basic"
        case .medium: return "Medium"
        case .advanced: return "Advanced"
        }
    }

    /// Thời gian cho phép mỗi từ trong Voice Runner (giây)
    public var timePerWord: TimeInterval {
        switch self {
        case .basic: return 3.5
        case .medium: return 2.8
        case .advanced: return 2.0
        }
    }

    /// Thời gian tính bằng milliseconds
    public var timeLimitPerWordMs: Int64 {
        return Int64(timePerWord * 1000)
    }

    /// Ngưỡng so khớp Levenshtein tối thiểu
    public var minimumLevenshteinThreshold: Double {
        switch self {
        case .basic: return 0.60
        case .medium: return 0.75
        case .advanced: return 0.85
        }
    }

    /// Cấp độ Khó (Advanced) bắt buộc bổ sung kiểm tra Levenshtein khi khớp âm
    public var requiresLevenshteinOnPhoneticMatch: Bool {
        switch self {
        case .basic, .medium:
            return false
        case .advanced:
            return true
        }
    }
}
