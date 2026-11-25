//
//  GameModeType.swift
//  VoiceFilter_iOS
//
//  3 Chế độ chơi chính của Nói Chuẩn (Voice Filter: Speak Challenge)
//

import Foundation

public enum GameModeType: String, CaseIterable, Codable, Identifiable {
    case voiceRunner = "voice_runner"
    case tongueTwister = "tongue_twister"
    case categoryRush = "category_rush"

    public var id: String { rawValue }

    public var titleVi: String {
        switch self {
        case .voiceRunner: return "Voice Runner"
        case .tongueTwister: return "Tongue Twister"
        case .categoryRush: return "30s Category Rush"
        }
    }

    public var titleEn: String {
        switch self {
        case .voiceRunner: return "Voice Runner"
        case .tongueTwister: return "Tongue Twister"
        case .categoryRush: return "Category Rush"
        }
    }

    public var descriptionVi: String {
        switch self {
        case .voiceRunner:
            return "Quickly read the incoming words to open gates and help the fox clear obstacles (3 lives)."
        case .tongueTwister:
            return "Pronounce long tongue twisters fluently without pausing more than 1.5s."
        case .categoryRush:
            return "Say as many words from the same category as you can in 30 seconds, without repeats."
        }
    }

    public var emoji: String {
        switch self {
        case .voiceRunner: return "🏃‍♂️"
        case .tongueTwister: return "👅"
        case .categoryRush: return "⚡"
        }
    }

    public var tag: String {
        switch self {
        case .voiceRunner: return "Classic"
        case .tongueTwister: return "Pronunciation"
        case .categoryRush: return "Reflex"
        }
    }

    public var defaultDurationSeconds: Int {
        switch self {
        case .voiceRunner: return 60
        case .tongueTwister: return 45
        case .categoryRush: return 30
        }
    }
}
