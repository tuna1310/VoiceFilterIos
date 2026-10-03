//
//  VideoCompositor.swift
//  VoiceFilter_iOS
//
//  Bộ kết xuất & ghép video (Video Compositor & Rendering Pipeline):
//  - Ghép video khuôn mặt (camera) với đồ họa game và watermark bản quyền
//  - Tự động gắn Watermark nhận diện thương hiệu Nói Chuẩn / Voice Filter
//  - Hòa âm nhạc nền (BGM loop) và các âm thanh hiệu ứng SFX (Ding, Buzz, Crash)
//    vào track âm thanh của file MP4 cuối cùng theo đúng timeline sự kiện trận đấu
//  - Xuất ra file MP4 chuẩn TikTok / Reels / Shorts (1080x1920, H.264, AAC)
//

import Foundation
import AVFoundation
import UIKit
import CoreGraphics
import QuartzCore

public struct CompositorOptions {
    public var includeWatermark: Bool
    public var includeAudioMix: Bool
    public var includeGameHUD: Bool
    public var bgmVolume: Float
    public var sfxVolume: Float

    public static let `default` = CompositorOptions(
        includeWatermark: true,
        includeAudioMix: true,
        includeGameHUD: true,
        bgmVolume: 0.22,
        sfxVolume: 0.75
    )

    public init(
        includeWatermark: Bool = true,
        includeAudioMix: Bool = true,
        includeGameHUD: Bool = true,
        bgmVolume: Float = 0.22,
        sfxVolume: Float = 0.75
    ) {
        self.includeWatermark = includeWatermark
        self.includeAudioMix = includeAudioMix
        self.includeGameHUD = includeGameHUD
        self.bgmVolume = bgmVolume
        self.sfxVolume = sfxVolume
    }
}

public enum VideoCompositorError: LocalizedError {
    case invalidSourceAsset
    case noVideoTrackFound
    case exportSessionFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidSourceAsset: return "File video nguồn không hợp lệ hoặc không tồn tại."
        case .noVideoTrackFound: return "Không tìm thấy track video trong file đã quay."
        case .exportSessionFailed(let msg): return "Xuất video thất bại: \(msg)"
        case .cancelled: return "Tiến trình kết xuất video đã bị hủy."
        }
    }
}

public final class VideoCompositor {
    public static let shared = VideoCompositor()

    private init() {}

    /// Kết xuất video hoàn chỉnh kết hợp khuôn mặt + watermark + timeline sự kiện game + hòa âm SFX/BGM
    public func compositeVideo(
        rawVideoURL: URL,
        timelineEvents: [GameTimelineEvent],
        words: [WordItem],
        gameResult: GameResult,
        options: CompositorOptions = .default,
        progressHandler: ((Float) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard FileManager.default.fileExists(atPath: rawVideoURL.path) else {
            completion(.failure(VideoCompositorError.invalidSourceAsset))
            return
        }

        let asset = AVURLAsset(url: rawVideoURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

        asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) { [weak self] in
            guard let self = self else { return }

            var error: NSError?
            let status = asset.statusOfValue(forKey: "tracks", error: &error)
            guard status == .loaded, error == nil else {
                DispatchQueue.main.async {
                    completion(.failure(error ?? VideoCompositorError.invalidSourceAsset))
                }
                return
            }

            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                DispatchQueue.main.async {
                    completion(.failure(VideoCompositorError.noVideoTrackFound))
                }
                return
            }

            self.performComposition(
                sourceAsset: asset,
                sourceVideoTrack: videoTrack,
                timelineEvents: timelineEvents,
                words: words,
                gameResult: gameResult,
                options: options,
                progressHandler: progressHandler,
                completion: completion
            )
        }
    }

    // MARK: - Internal Pipeline

    private func performComposition(
        sourceAsset: AVURLAsset,
        sourceVideoTrack: AVAssetTrack,
        timelineEvents: [GameTimelineEvent],
        words: [WordItem],
        gameResult: GameResult,
        options: CompositorOptions,
        progressHandler: ((Float) -> Void)?,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let composition = AVMutableComposition()
        let totalDuration = sourceAsset.duration

        // 1. Thêm Video Track gốc
        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            DispatchQueue.main.async { completion(.failure(VideoCompositorError.noVideoTrackFound)) }
            return
        }

        do {
            try compVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: totalDuration),
                of: sourceVideoTrack,
                at: .zero
            )
            compVideoTrack.preferredTransform = sourceVideoTrack.preferredTransform
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        // 2. Thêm Audio Track gốc từ microphone (nếu có)
        var audioMixParameters: [AVMutableAudioMixInputParameters] = []

        if let sourceAudioTrack = sourceAsset.tracks(withMediaType: .audio).first {
            if let compAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                try? compAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: totalDuration),
                    of: sourceAudioTrack,
                    at: .zero
                )
                let micMixParam = AVMutableAudioMixInputParameters(track: compAudioTrack)
                micMixParam.setVolume(1.0, at: .zero)
                audioMixParameters.append(micMixParam)
            }
        }

        // 3. Hòa âm Nhạc nền (BGM Loop) & Âm thanh hiệu ứng (SFX)
        if options.includeAudioMix {
            mixBGMAndSFX(
                into: composition,
                totalDuration: totalDuration,
                timelineEvents: timelineEvents,
                options: options,
                audioMixParameters: &audioMixParameters
            )
        }

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioMixParameters

        // 4. Xây dựng Video Composition & CoreAnimation Tool
        let naturalSize = sourceVideoTrack.naturalSize
        let transform = sourceVideoTrack.preferredTransform
        let isPortrait = (transform.a == 0 && abs(transform.b) == 1) || (transform.d == 0 && abs(transform.c) == 1)
        let renderWidth = isPortrait ? naturalSize.height : naturalSize.width
        let renderHeight = isPortrait ? naturalSize.width : naturalSize.height
        let renderSize = CGSize(width: renderWidth, height: renderHeight)

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: totalDuration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        layerInstruction.setTransform(sourceVideoTrack.preferredTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // 5. Tạo các lớp đồ họa CoreAnimation (Watermark, HUD, Event badges)
        let (parentLayer, videoLayer) = buildCoreAnimationLayers(
            renderSize: renderSize,
            totalDuration: totalDuration,
            timelineEvents: timelineEvents,
            words: words,
            gameResult: gameResult,
            options: options
        )

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        // 6. Xuất Video qua AVAssetExportSession
        exportFinalMP4(
            composition: composition,
            videoComposition: videoComposition,
            audioMix: audioMix,
            completion: completion
        )
    }

    // MARK: - CoreAnimation Layer Builder

    private func buildCoreAnimationLayers(
        renderSize: CGSize,
        totalDuration: CMTime,
        timelineEvents: [GameTimelineEvent],
        words: [WordItem],
        gameResult: GameResult,
        options: CompositorOptions
    ) -> (parentLayer: CALayer, videoLayer: CALayer) {
        let width = renderSize.width
        let height = renderSize.height

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        parentLayer.addSublayer(videoLayer)

        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        parentLayer.addSublayer(overlayLayer)

        let durationSec = totalDuration.seconds

        // 1. Watermark bản quyền góc trên (Viral Watermark Badge)
        if options.includeWatermark {
            let watermarkLayer = createWatermarkLayer(width: width, height: height)
            overlayLayer.addSublayer(watermarkLayer)
        }

        // 2. Game HUD cố định phía trên (Điểm số, Tim, Combo)
        if options.includeGameHUD {
            let hudLayer = createHUDLayer(width: width, height: height, finalScore: gameResult.finalScore)
            overlayLayer.addSublayer(hudLayer)
        }

        // 3. Dynamic Word Gates & Badges theo Timeline Sự Kiện
        for event in timelineEvents {
            let eventTimeSec = Double(event.timestampMs) / 1000.0
            guard eventTimeSec < durationSec else { continue }

            switch event.type {
            case .gateSpawn:
                let wordLayer = createWordBadgeLayer(word: event.payload, renderWidth: width, renderHeight: height)
                let appearAnim = CABasicAnimation(keyPath: "opacity")
                appearAnim.beginTime = AVCoreAnimationBeginTimeAtZero + eventTimeSec
                appearAnim.duration = 0.25
                appearAnim.fromValue = 0.0
                appearAnim.toValue = 1.0
                appearAnim.fillMode = .forwards
                appearAnim.isRemovedOnCompletion = false

                let disappearAnim = CABasicAnimation(keyPath: "opacity")
                disappearAnim.beginTime = AVCoreAnimationBeginTimeAtZero + eventTimeSec + 2.5
                disappearAnim.duration = 0.2
                disappearAnim.fromValue = 1.0
                disappearAnim.toValue = 0.0
                disappearAnim.fillMode = .forwards
                disappearAnim.isRemovedOnCompletion = false

                wordLayer.opacity = 0.0
                wordLayer.add(appearAnim, forKey: "word_appear_\(event.timestampMs)")
                wordLayer.add(disappearAnim, forKey: "word_disappear_\(event.timestampMs)")
                overlayLayer.addSublayer(wordLayer)

            case .gatePass:
                let successLayer = createResultBadgeLayer(
                    text: "✓ CHÍNH XÁC (+10)",
                    bgColor: UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 0.9),
                    renderWidth: width,
                    renderHeight: height
                )
                animateFlashBadge(layer: successLayer, atTime: eventTimeSec)
                overlayLayer.addSublayer(successLayer)

            case .gateCrash, .wordTimeout:
                let missLayer = createResultBadgeLayer(
                    text: "✗ BỎ LỠ (-1 TIM)",
                    bgColor: UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.9),
                    renderWidth: width,
                    renderHeight: height
                )
                animateFlashBadge(layer: missLayer, atTime: eventTimeSec)
                overlayLayer.addSublayer(missLayer)

            default:
                break
            }
        }

        // 4. Banner Kết Quả Cuối Trận (Stars & Final Score)
        if durationSec > 2.0 {
            let finalBadge = createFinalSummaryLayer(renderWidth: width, renderHeight: height, result: gameResult)
            let finalTime = max(durationSec - 2.5, 0.5)
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.beginTime = AVCoreAnimationBeginTimeAtZero + finalTime
            anim.duration = 0.4
            anim.fromValue = 0.0
            anim.toValue = 1.0
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false
            finalBadge.opacity = 0.0
            finalBadge.add(anim, forKey: "final_summary")
            overlayLayer.addSublayer(finalBadge)
        }

        return (parentLayer, videoLayer)
    }

    // MARK: - Layer Components

    private func createWatermarkLayer(width: CGFloat, height: CGFloat) -> CALayer {
        let badge = CALayer()
        let badgeWidth: CGFloat = 260
        let badgeHeight: CGFloat = 64
        // Đặt ở góc trên bên trái, cách mép trên 120pt (tránh tai thỏ / camera hole)
        badge.frame = CGRect(x: 36, y: height - badgeHeight - 120, width: badgeWidth, height: badgeHeight)
        badge.backgroundColor = UIColor.black.withAlphaComponent(0.65).cgColor
        badge.cornerRadius = 16
        badge.borderWidth = 1.5
        badge.borderColor = UIColor(red: 0.65, green: 0.93, blue: 0.15, alpha: 0.8).cgColor
        badge.shadowColor = UIColor.black.cgColor
        badge.shadowOpacity = 0.5
        badge.shadowOffset = CGSize(width: 0, height: 4)

        // Chữ chính
        let textLayer = CATextLayer()
        textLayer.frame = CGRect(x: 16, y: 30, width: badgeWidth - 32, height: 26)
        textLayer.string = "🎙️ Nói Chuẩn AR"
        textLayer.fontSize = 18
        textLayer.font = UIFont.boldSystemFont(ofSize: 18)
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.alignmentMode = .left
        badge.addSublayer(textLayer)

        // Chữ phụ
        let subTextLayer = CATextLayer()
        subTextLayer.frame = CGRect(x: 16, y: 10, width: badgeWidth - 32, height: 18)
        subTextLayer.string = "Voice Filter: Speak Challenge"
        subTextLayer.fontSize = 12
        subTextLayer.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        subTextLayer.foregroundColor = UIColor(red: 0.65, green: 0.93, blue: 0.15, alpha: 1.0).cgColor
        subTextLayer.contentsScale = UIScreen.main.scale
        subTextLayer.alignmentMode = .left
        badge.addSublayer(subTextLayer)

        return badge
    }

    private func createHUDLayer(width: CGFloat, height: CGFloat, finalScore: Int) -> CALayer {
        let hud = CALayer()
        let hudWidth: CGFloat = 220
        let hudHeight: CGFloat = 50
        // Đặt góc trên bên phải
        hud.frame = CGRect(x: width - hudWidth - 36, y: height - hudHeight - 120, width: hudWidth, height: hudHeight)
        hud.backgroundColor = UIColor.black.withAlphaComponent(0.65).cgColor
        hud.cornerRadius = 16
        hud.borderWidth = 1.2
        hud.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor

        let scoreText = CATextLayer()
        scoreText.frame = CGRect(x: 10, y: 12, width: hudWidth - 20, height: 28)
        scoreText.string = "⭐ \(finalScore) ĐIỂM"
        scoreText.fontSize = 16
        scoreText.font = UIFont.boldSystemFont(ofSize: 16)
        scoreText.foregroundColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor
        scoreText.contentsScale = UIScreen.main.scale
        scoreText.alignmentMode = .center
        hud.addSublayer(scoreText)

        return hud
    }

    private func createWordBadgeLayer(word: String, renderWidth: CGFloat, renderHeight: CGFloat) -> CALayer {
        let badge = CALayer()
        let badgeWidth: CGFloat = 340
        let badgeHeight: CGFloat = 80
        // Đặt ở vị trí 62% chiều cao màn hình (trên đường băng)
        badge.frame = CGRect(x: (renderWidth - badgeWidth) / 2, y: renderHeight * 0.62, width: badgeWidth, height: badgeHeight)
        badge.backgroundColor = UIColor.black.withAlphaComponent(0.85).cgColor
        badge.cornerRadius = 20
        badge.borderWidth = 3.0
        badge.borderColor = UIColor(red: 0.65, green: 0.93, blue: 0.15, alpha: 1.0).cgColor
        badge.shadowColor = UIColor(red: 0.65, green: 0.93, blue: 0.15, alpha: 0.6).cgColor
        badge.shadowOpacity = 0.8
        badge.shadowRadius = 12

        let text = CATextLayer()
        text.frame = CGRect(x: 10, y: 20, width: badgeWidth - 20, height: 40)
        text.string = word.uppercased()
        text.fontSize = 28
        text.font = UIFont.boldSystemFont(ofSize: 28)
        text.foregroundColor = UIColor.white.cgColor
        text.contentsScale = UIScreen.main.scale
        text.alignmentMode = .center
        badge.addSublayer(text)

        return badge
    }

    private func createResultBadgeLayer(text: String, bgColor: UIColor, renderWidth: CGFloat, renderHeight: CGFloat) -> CALayer {
        let layer = CALayer()
        let w: CGFloat = 280
        let h: CGFloat = 50
        layer.frame = CGRect(x: (renderWidth - w) / 2, y: renderHeight * 0.50, width: w, height: h)
        layer.backgroundColor = bgColor.cgColor
        layer.cornerRadius = 25

        let t = CATextLayer()
        t.frame = CGRect(x: 10, y: 12, width: w - 20, height: 28)
        t.string = text
        t.fontSize = 18
        t.font = UIFont.boldSystemFont(ofSize: 18)
        t.foregroundColor = UIColor.white.cgColor
        t.contentsScale = UIScreen.main.scale
        t.alignmentMode = .center
        layer.addSublayer(t)

        return layer
    }

    private func animateFlashBadge(layer: CALayer, atTime: Double) {
        layer.opacity = 0.0

        let appear = CABasicAnimation(keyPath: "opacity")
        appear.beginTime = AVCoreAnimationBeginTimeAtZero + atTime
        appear.duration = 0.15
        appear.fromValue = 0.0
        appear.toValue = 1.0
        appear.fillMode = .forwards
        appear.isRemovedOnCompletion = false

        let disappear = CABasicAnimation(keyPath: "opacity")
        disappear.beginTime = AVCoreAnimationBeginTimeAtZero + atTime + 1.2
        disappear.duration = 0.25
        disappear.fromValue = 1.0
        disappear.toValue = 0.0
        disappear.fillMode = .forwards
        disappear.isRemovedOnCompletion = false

        layer.add(appear, forKey: "flash_in_\(atTime)")
        layer.add(disappear, forKey: "flash_out_\(atTime)")
    }

    private func createFinalSummaryLayer(renderWidth: CGFloat, renderHeight: CGFloat, result: GameResult) -> CALayer {
        let card = CALayer()
        let cardWidth: CGFloat = 380
        let cardHeight: CGFloat = 160
        card.frame = CGRect(x: (renderWidth - cardWidth) / 2, y: renderHeight * 0.40, width: cardWidth, height: cardHeight)
        card.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 0.95).cgColor
        card.cornerRadius = 24
        card.borderWidth = 2.5
        card.borderColor = UIColor(red: 0.65, green: 0.93, blue: 0.15, alpha: 1.0).cgColor
        card.shadowColor = UIColor.black.cgColor
        card.shadowOpacity = 0.7
        card.shadowRadius = 15

        let starText = CATextLayer()
        starText.frame = CGRect(x: 10, y: 100, width: cardWidth - 20, height: 40)
        let starStr = String(repeating: "⭐ ", count: max(result.stars, 1)).trimmingCharacters(in: .whitespaces)
        starText.string = starStr
        starText.fontSize = 28
        starText.font = UIFont.systemFont(ofSize: 28)
        starText.contentsScale = UIScreen.main.scale
        starText.alignmentMode = .center
        card.addSublayer(starText)

        let titleText = CATextLayer()
        titleText.frame = CGRect(x: 10, y: 60, width: cardWidth - 20, height: 32)
        titleText.string = result.stars >= 2 ? "🎉 THỬ THÁCH HOÀN THÀNH!" : "💪 CỐ GẮNG LẦN SAU!"
        titleText.fontSize = 20
        titleText.font = UIFont.boldSystemFont(ofSize: 20)
        titleText.foregroundColor = UIColor.white.cgColor
        titleText.contentsScale = UIScreen.main.scale
        titleText.alignmentMode = .center
        card.addSublayer(titleText)

        let scoreText = CATextLayer()
        scoreText.frame = CGRect(x: 10, y: 20, width: cardWidth - 20, height: 30)
        scoreText.string = "TỔNG ĐIỂM: \(result.finalScore) • CHÍNH XÁC: \(Int(result.accuracyPercent))%"
        scoreText.fontSize = 15
        scoreText.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        scoreText.foregroundColor = UIColor(red: 0.65, green: 0.93, blue: 0.15, alpha: 1.0).cgColor
        scoreText.contentsScale = UIScreen.main.scale
        scoreText.alignmentMode = .center
        card.addSublayer(scoreText)

        return card
    }

    // MARK: - Audio Mixing (BGM & SFX)

    private func mixBGMAndSFX(
        into composition: AVMutableComposition,
        totalDuration: CMTime,
        timelineEvents: [GameTimelineEvent],
        options: CompositorOptions,
        audioMixParameters: inout [AVMutableAudioMixInputParameters]
    ) {
        let totalDurationSec = totalDuration.seconds

        // 1. Loop BGM
        if let bgmURL = findAudioURL(name: "bgm", ext: "wav") {
            let bgmAsset = AVURLAsset(url: bgmURL)
            if let bgmTrack = bgmAsset.tracks(withMediaType: .audio).first {
                if let compBGMTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) {
                    let bgmDuration = bgmAsset.duration.seconds
                    if bgmDuration > 0 {
                        var currentTime: Double = 0.0
                        while currentTime < totalDurationSec {
                            let remain = totalDurationSec - currentTime
                            let chunkSec = min(remain, bgmDuration)
                            let chunkRange = CMTimeRange(
                                start: .zero,
                                duration: CMTime(seconds: chunkSec, preferredTimescale: 600)
                            )
                            let atTime = CMTime(seconds: currentTime, preferredTimescale: 600)
                            try? compBGMTrack.insertTimeRange(chunkRange, of: bgmTrack, at: atTime)
                            currentTime += chunkSec
                        }

                        let bgmParam = AVMutableAudioMixInputParameters(track: compBGMTrack)
                        bgmParam.setVolume(options.bgmVolume, at: .zero)
                        audioMixParameters.append(bgmParam)
                    }
                }
            }
        }

        // 2. Chèn SFX theo từng sự kiện timeline
        guard let compSFXTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { return }

        let dingAsset = findAudioURL(name: "ding", ext: "wav").map { AVURLAsset(url: $0) }
        let buzzAsset = findAudioURL(name: "buzz", ext: "wav").map { AVURLAsset(url: $0) }
        let crashAsset = findAudioURL(name: "crash", ext: "wav").map { AVURLAsset(url: $0) }

        for event in timelineEvents {
            let eventTimeSec = Double(event.timestampMs) / 1000.0
            guard eventTimeSec < totalDurationSec else { continue }
            let atTime = CMTime(seconds: eventTimeSec, preferredTimescale: 600)

            var targetAsset: AVURLAsset? = nil
            switch event.type {
            case .gatePass:
                targetAsset = dingAsset
            case .gateCrash:
                targetAsset = crashAsset
            case .wordTimeout:
                targetAsset = buzzAsset
            default:
                break
            }

            if let sfx = targetAsset, let track = sfx.tracks(withMediaType: .audio).first {
                let range = CMTimeRange(start: .zero, duration: min(sfx.duration, CMTime(seconds: 1.0, preferredTimescale: 600)))
                try? compSFXTrack.insertTimeRange(range, of: track, at: atTime)
            }
        }

        let sfxParam = AVMutableAudioMixInputParameters(track: compSFXTrack)
        sfxParam.setVolume(options.sfxVolume, at: .zero)
        audioMixParameters.append(sfxParam)
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

    // MARK: - Export Session

    private func exportFinalMP4(
        composition: AVComposition,
        videoComposition: AVVideoComposition,
        audioMix: AVAudioMix,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceFilter_Composited_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            DispatchQueue.main.async {
                completion(.failure(VideoCompositorError.exportSessionFailed("Không thể khởi tạo AVAssetExportSession.")))
            }
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.audioMix = audioMix
        exportSession.shouldOptimizeForNetworkUse = true

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    print("[VideoCompositor] Render video with Watermark & SFX successful: \(outputURL.path)")
                    completion(.success(outputURL))
                case .failed:
                    let err = exportSession.error ?? VideoCompositorError.exportSessionFailed("Lỗi không xác định.")
                    print("[VideoCompositor] Export failed: \(err.localizedDescription)")
                    completion(.failure(err))
                case .cancelled:
                    completion(.failure(VideoCompositorError.cancelled))
                default:
                    completion(.failure(VideoCompositorError.exportSessionFailed("Trạng thái: \(exportSession.status.rawValue)")))
                }
            }
        }
    }
}
