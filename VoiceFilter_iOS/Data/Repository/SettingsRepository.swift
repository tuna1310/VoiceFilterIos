//
//  SettingsRepository.swift
//  VoiceFilter_iOS
//
//  Quản lý cài đặt ứng dụng: Ngôn ngữ, Âm lượng SFX/BGM, Điểm số cao nhất
//

import Foundation
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case vietnamese = "vi"
    case english = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt 🇻🇳"
        case .english: return "English 🇺🇸"
        }
    }
}

public final class SettingsRepository: ObservableObject {
    public static let shared = SettingsRepository()

    @Published public var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "app_language") }
    }

    @Published public var sfxVolume: Float {
        didSet { UserDefaults.standard.set(sfxVolume, forKey: "sfx_volume") }
    }

    @Published public var bgmVolume: Float {
        didSet { UserDefaults.standard.set(bgmVolume, forKey: "bgm_volume") }
    }

    @Published public var preferOnDeviceSpeech: Bool {
        didSet { UserDefaults.standard.set(preferOnDeviceSpeech, forKey: "prefer_on_device_speech") }
    }

    @Published public var highScore: Int {
        didSet { UserDefaults.standard.set(highScore, forKey: "high_score") }
    }

    @Published public var dailyStreak: Int {
        didSet { UserDefaults.standard.set(dailyStreak, forKey: "daily_streak") }
    }

    public init() {
        let savedLang = UserDefaults.standard.string(forKey: "app_language") ?? "vi"
        self.language = AppLanguage(rawValue: savedLang) ?? .vietnamese
        self.sfxVolume = UserDefaults.standard.object(forKey: "sfx_volume") != nil ? UserDefaults.standard.float(forKey: "sfx_volume") : 0.8
        self.bgmVolume = UserDefaults.standard.object(forKey: "bgm_volume") != nil ? UserDefaults.standard.float(forKey: "bgm_volume") : 0.25
        self.preferOnDeviceSpeech = UserDefaults.standard.object(forKey: "prefer_on_device_speech") != nil ? UserDefaults.standard.bool(forKey: "prefer_on_device_speech") : true
        self.highScore = UserDefaults.standard.integer(forKey: "high_score")
        let streak = UserDefaults.standard.integer(forKey: "daily_streak")
        self.dailyStreak = streak > 0 ? streak : 3 // Mặc định streak 3 ngày tạo động lực
    }

    public func updateHighScore(score: Int) {
        if score > highScore {
            highScore = score
        }
    }
}
