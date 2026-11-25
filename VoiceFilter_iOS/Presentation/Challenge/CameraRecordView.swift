//
//  CameraRecordView.swift
//  VoiceFilter_iOS
//
//  Giao diện Thử Thách Phát Âm AR (CameraRecordView / ChallengeView):
//  - Camera trước 9:16 toàn màn hình
//  - Canvas 3D Isometric: Đường chạy màu xanh chanh, Chú cáo khối hộp, Cổng từ vựng
//  - Game HUD: 3 Tim (lives), Điểm số, Chuỗi Combo, Thanh đếm ngược từng từ
//  - Hiệu ứng pháo giấy Confetti và Banner điểm số khi đúng
//  - Hiệu ứng rung lắc (Shake) và phản hồi xúc giác (Haptic) khi sai/hết giờ
//  - Tự động xuất Video hoàn chỉnh có Watermark & SFX qua VideoCompositor
//  - Xem lại video MP4 sau khi hoàn tất trận đấu + Lưu thư viện + Chia sẻ 1-chạm
//

import SwiftUI
import AVKit

public struct CameraRecordView: View {
    @StateObject private var viewModel = CameraRecordViewModel()
    @Environment(\.presentationMode) var presentationMode

    public let subject: Subject
    public let difficulty: DifficultyLevel
    public let gameMode: GameModeType
    public let words: [WordItem]
    public var onFinish: ((GameResult) -> Void)? = nil

    @State private var showExitAlert = false

    public init(
        subject: Subject = .colors,
        difficulty: DifficultyLevel = .basic,
        gameMode: GameModeType = .voiceRunner,
        words: [WordItem] = [],
        onFinish: ((GameResult) -> Void)? = nil
    ) {
        self.subject = subject
        self.difficulty = difficulty
        self.gameMode = gameMode
        self.words = words
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 1. Camera Preview 9:16 Toàn Màn Hình
            if viewModel.isSessionReady {
                CameraPreviewView(previewLayer: viewModel.cameraManager.previewLayer)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    ProgressView().tint(.white).scaleEffect(1.4)
                    Text("Starting AR camera...")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                }
            }

            // 2. Lớp Đồ Họa AR Canvas 3D Isometric (Đường chạy + Chú Cáo + Cổng)
            if case .playing(let ps) = viewModel.gameState {
                IsometricFilterCanvas(
                    currentWord: ps.currentWord,
                    nextWord: ps.nextWord,
                    gateProgress: ps.gateProgress,
                    isRunning: true,
                    isGateSuccess: ps.isGateSuccess
                )
                .ignoresSafeArea()
                .modifier(ShakeEffect(animatableData: viewModel.triggerErrorShake ? 1.0 : 0.0))
            } else if case .paused(let ps) = viewModel.gameState {
                IsometricFilterCanvas(
                    currentWord: ps.currentWord,
                    nextWord: ps.nextWord,
                    gateProgress: ps.gateProgress,
                    isRunning: false,
                    isGateSuccess: ps.isGateSuccess
                )
                .ignoresSafeArea()
            }

            // 3. Pháo Giấy Confetti tung bay khi vượt cổng thành công
            if viewModel.showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }

            // 4. Banner Cộng Điểm (+10đ / +30đ) nhảy lên giữa màn hình
            if let banner = viewModel.plusPointsBanner {
                VStack {
                    Text(banner)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
                        .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 3)
                        .transition(.scale.combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            // 5. Giao diện Game HUD & Điều Khiển
            VStack {
                // Top Bar
                topControlBar

                // Thanh Trạng Thái Trận Đấu (Tim, Điểm, Combo, Thanh thời gian từ)
                if case .playing(let ps) = viewModel.gameState {
                    gameHeaderHUD(ps: ps)
                        .modifier(ShakeEffect(animatableData: viewModel.triggerErrorShake ? 1.0 : 0.0))
                }

                Spacer()

                // Bong bóng giọng nói trực tiếp (Live Speech Transcript)
                speechTranscriptBubble
                    .modifier(ShakeEffect(animatableData: viewModel.triggerErrorShake ? 1.0 : 0.0))

                // Thanh điều khiển phía dưới (Nút dừng/thoát)
                bottomControlBar
            }
            .padding(.top, 44)
            .padding(.bottom, 20)

            // 6. Màn hình Đếm ngược 3-2-1 trước khi bắt đầu
            if case .countdown(let sec) = viewModel.gameState {
                CountdownBannerView(count: sec)
            }

            // 7. Hộp thoại Tạm dừng (Pause Modal)
            if case .paused = viewModel.gameState {
                pauseOverlay
            }

            // 8. Lớp phủ đang kết xuất video MP4 TikTok (Compositor Loading Overlay)
            if viewModel.isCompositingVideo {
                compositingLoadingOverlay
            }
        }
        .onAppear {
            let gameWords = words.isEmpty ? VocabularyRepository.shared.getWords(for: subject, difficulty: difficulty, gameMode: gameMode) : words
            viewModel.startGame(subject: subject, difficulty: difficulty, gameMode: gameMode, words: gameWords)
        }
        .onDisappear {
            viewModel.stopAll()
        }
        .sheet(isPresented: $viewModel.showVideoPreview) {
            if let url = viewModel.recordedVideoURL {
                ResultView(
                    result: extractCurrentResult(),
                    videoURL: url,
                    onPlayAgain: {
                        viewModel.showVideoPreview = false
                        let gameWords = words.isEmpty ? VocabularyRepository.shared.getWords(for: subject, difficulty: difficulty, gameMode: gameMode) : words
                        viewModel.startGame(subject: subject, difficulty: difficulty, gameMode: gameMode, words: gameWords)
                    },
                    onGoHome: {
                        viewModel.showVideoPreview = false
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .alert(isPresented: $showExitAlert) {
            Alert(
                title: Text("Stop the challenge?"),
                message: Text("Progress and score for this round will be lost."),
                primaryButton: .destructive(Text("Quit")) {
                    viewModel.stopAll()
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text("Continue")) {
                    viewModel.resumeGame()
                }
            )
        }
    }

    // MARK: - Subviews

    private var topControlBar: some View {
        HStack(spacing: 12) {
            // Nút Thoát
            Button(action: {
                viewModel.pauseGame()
                showExitAlert = true
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            // Huy hiệu Watermark bản quyền
            WatermarkBadgeView()

            Spacer()

            // Badge nhận diện giọng nói On-Device vs Cloud
            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.isOnDeviceSpeech ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(viewModel.isOnDeviceSpeech ? "⚡ On-Device" : "🌐 Apple Cloud")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .cornerRadius(16)

            // Nút Đổi Camera
            Button(action: { viewModel.switchCamera() }) {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
    }

    private func gameHeaderHUD(ps: PlayingState) -> some View {
        VStack(spacing: 8) {
            HStack {
                // Mạng sống (3 Tim)
                HStack(spacing: 4) {
                    ForEach(0..<ps.maxLives, id: \.self) { idx in
                        Image(systemName: idx < ps.livesRemaining ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(idx < ps.livesRemaining ? .red : .gray.opacity(0.6))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(14)

                Spacer()

                // Combo Badge
                if ps.combo > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("x\(ps.combo)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                }

                // Điểm số
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(ps.score)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
            }
            .padding(.horizontal, 16)

            // Thanh tiến trình thời gian của từ vựng hiện tại (Reaction Timer Bar)
            if ps.wordTimeLimitMs > 0 {
                let progress = min(CGFloat(ps.wordElapsedMs) / CGFloat(ps.wordTimeLimitMs), 1.0)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)

                        Capsule()
                            .fill(progress > 0.75 ? Color.red : (progress > 0.5 ? Color.orange : Color(red: 0.65, green: 0.93, blue: 0.15)))
                            .frame(width: max(geo.size.width * (1.0 - progress), 0), height: 6)
                            .animation(.linear(duration: 0.05), value: progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 20)
            }
        }
    }

    private var speechTranscriptBubble: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundColor(viewModel.triggerErrorShake ? .red : Color(red: 0.65, green: 0.93, blue: 0.15))
                .font(.system(size: 18))

            Text(viewModel.liveSpeechTranscript.isEmpty ? "Read the word on screen out loud..." : viewModel.liveSpeechTranscript)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(viewModel.liveSpeechTranscript.isEmpty ? .gray : (viewModel.triggerErrorShake ? .red : .white))
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(viewModel.triggerErrorShake ? Color.red.opacity(0.7) : Color.white.opacity(0.2), lineWidth: 1.2)
                )
        )
        .padding(.horizontal, 16)
    }

    private var bottomControlBar: some View {
        HStack {
            Spacer()
            // Nút Tạm dừng
            Button(action: {
                viewModel.pauseGame()
            }) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            Spacer()
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("PAUSED")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Button(action: { viewModel.resumeGame() }) {
                    Text("Resume")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.65, green: 0.93, blue: 0.15))
                        .cornerRadius(24)
                }

                Button(action: {
                    viewModel.stopAll()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Back to Home")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                }
            }
            .padding(32)
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .cornerRadius(24)
            .padding(.horizontal, 40)
        }
    }

    private var compositingLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.65, green: 0.93, blue: 0.15)))
                    .scaleEffect(1.6)

                Text(viewModel.compositingStatusText.isEmpty ? "Processing video..." : viewModel.compositingStatusText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Applying Speak Right watermark & mixing SFX...")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(red: 0.65, green: 0.93, blue: 0.15).opacity(0.4), lineWidth: 1.5)
            )
            .padding(.horizontal, 36)
        }
    }

    private func extractCurrentResult() -> GameResult {
        if let res = viewModel.lastGameResult {
            return res
        }
        if case .finished(let res) = viewModel.gameState {
            return res
        }
        return viewModel.stateMachine.buildCurrentResult()
    }
}

// MARK: - Shake Animation Effect
public struct ShakeEffect: GeometryEffect {
    public var amount: CGFloat = 8
    public var shakesPerUnit = 3
    public var animatableData: CGFloat

    public func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}
