//
//  AudioSessionManager.swift
//  VoiceFilter_iOS
//
//  Quản lý cấu hình AVAudioSession tập trung cho toàn bộ ứng dụng:
//  - Đảm bảo Camera, AVAssetWriter và SFSpeechRecognizer chạy đồng thời không xung đột.
//  - Chế độ .playAndRecord + .videoRecording + .mixWithOthers + .defaultToSpeaker.
//

import Foundation
import AVFoundation

public final class AudioSessionManager {
    public static let shared = AudioSessionManager()

    private let session = AVAudioSession.sharedInstance()
    private var isConfigured = false

    private init() {
        setupNotifications()
    }

    /// Cấu hình AudioSession cho ghi hình đồng thời và nhận diện giọng nói
    public func configureForRecordingAndSpeech() throws {
        // Tránh cấu hình lặp lại không cần thiết
        guard !isConfigured else { return }

        try session.setCategory(
            .playAndRecord,
            mode: .videoRecording,
            options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .mixWithOthers
            ]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        isConfigured = true
    }

    /// Deactivate audio session khi dừng toàn bộ hoạt động
    public func deactivate() {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            isConfigured = false
        } catch {
            print("[AudioSessionManager] Deactivate failed: \(error.localizedDescription)")
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("[AudioSessionManager] Audio Interruption Began (Call or Alarm)")
            isConfigured = false
        case .ended:
            print("[AudioSessionManager] Audio Interruption Ended")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? configureForRecordingAndSpeech()
                }
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            print("[AudioSessionManager] Route change: Headphones disconnected -> Default to speaker")
            try? configureForRecordingAndSpeech()
        default:
            break
        }
    }
}
