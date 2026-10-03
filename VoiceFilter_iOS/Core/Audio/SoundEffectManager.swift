//
//  SoundEffectManager.swift
//  VoiceFilter_iOS
//
//  Quản lý âm thanh hiệu ứng (SFX) và nhạc nền (BGM):
//  - Preload ding.wav, buzz.wav, crash.wav, bgm.wav
//  - Điều chỉnh âm lượng độc lập cho SFX và BGM
//  - Lặp vô tận nhạc nền (BGM loop) ở mức âm lượng dịu nhẹ
//

import Foundation
import AVFoundation

public final class SoundEffectManager: ObservableObject {
    public static let shared = SoundEffectManager()

    private var dingPlayer: AVAudioPlayer?
    private var buzzPlayer: AVAudioPlayer?
    private var crashPlayer: AVAudioPlayer?
    private var bgmPlayer: AVAudioPlayer?

    private let settings = SettingsRepository.shared

    public init() {
        preloadAudio()
    }

    private func findAudioURL(name: String, ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio") { return url }
        if let url = Bundle.module.url(forResource: name, withExtension: ext) { return url }

        let currentDir = FileManager.default.currentDirectoryPath
        let fallbackPath = "\(currentDir)/VoiceFilter_iOS/VoiceFilter_iOS/Resources/Audio/\(name).\(ext)"
        if FileManager.default.fileExists(atPath: fallbackPath) {
            return URL(fileURLWithPath: fallbackPath)
        }
        return nil
    }

    public func preloadAudio() {
        if let dingURL = findAudioURL(name: "ding", ext: "wav") {
            dingPlayer = try? AVAudioPlayer(contentsOf: dingURL)
            dingPlayer?.prepareToPlay()
        }
        if let buzzURL = findAudioURL(name: "buzz", ext: "wav") {
            buzzPlayer = try? AVAudioPlayer(contentsOf: buzzURL)
            buzzPlayer?.prepareToPlay()
        }
        if let crashURL = findAudioURL(name: "crash", ext: "wav") {
            crashPlayer = try? AVAudioPlayer(contentsOf: crashURL)
            crashPlayer?.prepareToPlay()
        }
        if let bgmURL = findAudioURL(name: "bgm", ext: "wav") {
            bgmPlayer = try? AVAudioPlayer(contentsOf: bgmURL)
            bgmPlayer?.numberOfLoops = -1 // Lặp vô tận
            bgmPlayer?.prepareToPlay()
        }
        updateVolumes()
    }

    public func updateVolumes() {
        dingPlayer?.volume = settings.sfxVolume
        buzzPlayer?.volume = settings.sfxVolume
        crashPlayer?.volume = settings.sfxVolume
        bgmPlayer?.volume = settings.bgmVolume
    }

    /// Phát âm thanh chuông mừng khi phát âm chuẩn (Success Chime)
    public func playSuccess() {
        guard settings.sfxVolume > 0 else { return }
        dingPlayer?.currentTime = 0
        dingPlayer?.volume = settings.sfxVolume
        dingPlayer?.play()
    }

    /// Phát âm thanh còi báo lỗi khi phát âm sai (Error Buzzer)
    public func playError() {
        guard settings.sfxVolume > 0 else { return }
        buzzPlayer?.currentTime = 0
        buzzPlayer?.volume = settings.sfxVolume
        buzzPlayer?.play()
    }

    /// Phát âm thanh va chạm khi mất mạng / Game Over (Crash Tone)
    public func playCrash() {
        guard settings.sfxVolume > 0 else { return }
        crashPlayer?.currentTime = 0
        crashPlayer?.volume = settings.sfxVolume
        crashPlayer?.play()
    }

    /// Bật nhạc nền nhẹ nhàng (BGM)
    public func startBGM() {
        guard settings.bgmVolume > 0 else { return }
        bgmPlayer?.volume = settings.bgmVolume
        if bgmPlayer?.isPlaying == false {
            bgmPlayer?.play()
        }
    }

    /// Tạm dừng nhạc nền
    public func pauseBGM() {
        bgmPlayer?.pause()
    }

    /// Dừng hẳn nhạc nền
    public func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer?.currentTime = 0
    }
}
