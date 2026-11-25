//
//  ResultView.swift
//  VoiceFilter_iOS
//
//  Màn hình Kết Quả Trận Đấu (ResultScreen):
//  - Hiển thị Điểm số, Đánh giá số sao (1-3 sao), Tỷ lệ chính xác, Combo cao nhất
//  - Trình phát video xem lại thước phim AR đã ghép Watermark & SFX (AVPlayer)
//  - Nút chia sẻ 1-chạm (One-tap Share) trực tiếp lên TikTok, Instagram Stories, Facebook
//  - Nút Lưu video chất lượng cao vào Thư viện ảnh (Photo Library)
//  - Nút Chơi lại và Về trang chủ
//

import SwiftUI
import AVKit

public struct ResultView: View {
    public let result: GameResult
    public let videoURL: URL
    public let onPlayAgain: () -> Void
    public let onGoHome: () -> Void

    @State private var player: AVPlayer?
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var showShareSheet = false
    @State private var alertMessage: String? = nil
    @State private var showAlert = false

    private let shareManager = SocialShareManager.shared

    public init(
        result: GameResult,
        videoURL: URL,
        onPlayAgain: @escaping () -> Void,
        onGoHome: @escaping () -> Void
    ) {
        self.result = result
        self.videoURL = videoURL
        self.onPlayAgain = onPlayAgain
        self.onGoHome = onGoHome
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header Tiêu đề
                    Text(result.stars == 3 ? "🎉 EXCELLENT!" : (result.stars == 2 ? "👏 GREAT JOB!" : "💪 KEEP GOING!"))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
                        .padding(.top, 24)

                    // Đánh giá Sao (1 - 3 sao)
                    HStack(spacing: 8) {
                        ForEach(1...3, id: \.self) { idx in
                            Image(systemName: idx <= result.stars ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundColor(idx <= result.stars ? .yellow : .gray.opacity(0.5))
                        }
                    }

                    // Thẻ Video Preview phát lại thước phim AR đã ghép Watermark
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Your finished AR clip:")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            HStack(spacing: 4) {
                                Circle().fill(Color(red: 0.65, green: 0.93, blue: 0.15)).frame(width: 6, height: 6)
                                Text("Watermark & SFX applied")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
                            }
                        }

                        if let player = player {
                            VideoPlayer(player: player)
                                .frame(height: 320)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)

                    // Lưới Thống kê kết quả
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            StatBox(title: "Total Score", value: "\(result.finalScore)", icon: "star.fill", color: .yellow)
                            StatBox(title: "Words Cleared", value: "\(result.wordsCompleted)/\(result.totalWords)", icon: "checkmark.circle.fill", color: Color(red: 0.65, green: 0.93, blue: 0.15))
                        }
                        HStack(spacing: 12) {
                            StatBox(title: "Accuracy", value: "\(Int(result.accuracyPercent))%", icon: "target", color: .cyan)
                            StatBox(title: "Combo Max", value: "x\(result.maxCombo)", icon: "flame.fill", color: .orange)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Thông báo đã lưu
                    if let msg = saveMessage {
                        Text(msg)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(12)
                    }

                    // MARK: - Mục Chia Sẻ Mạng Xã Hội 1-Chạm (Viral One-Tap Sharing)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Share to social media:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 20)

                        HStack(spacing: 10) {
                            // 1. TikTok 1-chạm
                            Button(action: shareToTikTok) {
                                HStack(spacing: 6) {
                                    Text("🎵")
                                    Text("TikTok")
                                        .font(.system(size: 14, weight: .black))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.cyan.opacity(0.6), lineWidth: 1.5)
                                )
                            }

                            // 2. Instagram Story 1-chạm
                            Button(action: shareToInstagram) {
                                HStack(spacing: 6) {
                                    Text("📸")
                                    Text("IG Story")
                                        .font(.system(size: 14, weight: .black))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.88, green: 0.19, blue: 0.42), Color(red: 0.98, green: 0.70, blue: 0.22)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }

                            // 3. Facebook 1-chạm
                            Button(action: shareToFacebook) {
                                HStack(spacing: 6) {
                                    Text("📘")
                                    Text("Facebook")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.18, green: 0.44, blue: 0.88))
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Nhóm nút Lưu & Chia sẻ hệ thống
                    HStack(spacing: 12) {
                        Button(action: saveVideo) {
                            HStack(spacing: 6) {
                                if isSaving {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "square.and.arrow.down.fill")
                                }
                                Text(isSaving ? "Saving..." : "Save to Library")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        }
                        .disabled(isSaving)

                        Button(action: { showShareSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text("More...")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Nhóm nút Chơi lại & Trang chủ
                    VStack(spacing: 12) {
                        Button(action: onPlayAgain) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Play Again")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.65, green: 0.93, blue: 0.15))
                            .cornerRadius(24)
                        }

                        Button(action: onGoHome) {
                            Text("Back to Home")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            let p = AVPlayer(url: videoURL)
            self.player = p
            p.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [videoURL])
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Share"),
                message: Text(alertMessage ?? ""),
                primaryButton: .default(Text("Open Share Sheet")) {
                    showShareSheet = true
                },
                secondaryButton: .cancel(Text("Close"))
            )
        }
    }

    private func saveVideo() {
        isSaving = true
        PhotoLibraryExporter.shared.saveVideoToAlbum(fileURL: videoURL) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success:
                    self.saveMessage = "Video saved to Photo Library!"
                case .failure(let err):
                    self.saveMessage = "Save error: \(err.localizedDescription)"
                }
            }
        }
    }

    private func shareToInstagram() {
        shareManager.shareToInstagramStories(videoURL: videoURL) { success, errMsg in
            if !success {
                self.alertMessage = errMsg ?? "Couldn't open Instagram Stories."
                self.showAlert = true
            }
        }
    }

    private func shareToTikTok() {
        shareManager.shareToTikTok(videoURL: videoURL) { success, errMsg in
            if !success {
                self.alertMessage = errMsg ?? "Couldn't open TikTok."
                self.showAlert = true
            }
        }
    }

    private func shareToFacebook() {
        shareManager.shareToFacebookStories(videoURL: videoURL) { success, errMsg in
            if !success {
                self.alertMessage = errMsg ?? "Couldn't open Facebook Stories."
                self.showAlert = true
            }
        }
    }
}

private struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .cornerRadius(16)
    }
}

public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
