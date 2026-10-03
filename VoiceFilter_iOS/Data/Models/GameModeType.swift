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
        case .tongueTwister: return "Líu Lưỡi (Tongue Twister)"
        case .categoryRush: return "Đua Từ 30s (Category Rush)"
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
            return "Đọc nhanh các từ đang lao tới để mở cổng và giúp chú cáo vượt chướng ngại vật (3 mạng)."
        case .tongueTwister:
            return "Thử thách phát âm câu dài líu lưỡi với nhịp đọc trôi chảy, không ngắt quãng quá 1.5s."
        case .categoryRush:
            return "Nói càng nhiều từ thuộc cùng chủ đề trong 30 giây càng tốt, không trùng lặp từ."
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
        case .voiceRunner: return "Cổ điển"
        case .tongueTwister: return "Luyện âm"
        case .categoryRush: return "Phản xạ"
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
