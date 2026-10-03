//
//  AppConfiguration.swift
//  VoiceFilter_iOS
//
//  Cấu hình tham số và hằng số toàn cục của ứng dụng.
//

import Foundation

public struct AppConfiguration {
    public static let appName = "Voice Filter: Speak Challenge"
    public static let appVersion = "1.0.0"

    // Độ phân giải video mặc định (Portrait 9:16)
    public static let videoTargetWidth = 1080
    public static let videoTargetHeight = 1920
    public static let videoFallbackWidth = 720
    public static let videoFallbackHeight = 1280

    // Frame rate & bitrate
    public static let videoFPS = 30
    public static let videoBitrate = 8_000_000 // 8 Mbps

    // Audio bit rate
    public static let audioSampleRate: Double = 44100.0
    public static let audioBitrate = 128_000

    // Remote Content & Supabase Placeholder
    public static let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://your-project.supabase.co"
    public static let supabaseAnonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "placeholder-key"
}
