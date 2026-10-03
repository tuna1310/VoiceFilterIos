//
//  HomeView.swift
//  VoiceFilter_iOS
//
//  Màn hình Trang Chủ (HomeScreen):
//  - Hero Card: Thử thách ngẫu nhiên nhanh (Quick Play) & Chuỗi ngày học (Daily Streak)
//  - 3 Thẻ Chế độ chơi chính: Voice Runner, Tongue Twister, Category Rush
//  - Danh sách Chủ đề luyện phát âm nổi bật
//

import SwiftUI

public struct HomeView: View {
    @ObservedObject private var settings = SettingsRepository.shared
    @ObservedObject private var vocabRepo = VocabularyRepository.shared

    public let onSelectChallenge: (Subject, DifficultyLevel, GameModeType) -> Void
    public let onSelectSubject: (Subject) -> Void
    public let onOpenSettings: () -> Void

    public init(
        onSelectChallenge: @escaping (Subject, DifficultyLevel, GameModeType) -> Void,
        onSelectSubject: @escaping (Subject) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.onSelectChallenge = onSelectChallenge
        self.onSelectSubject = onSelectSubject
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NÓI CHUẨN")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Luyện phát âm AR cùng chú cáo")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        // Chuỗi ngày học
                        HStack(spacing: 4) {
                            Text("🔥")
                            Text("\(settings.dailyStreak) Ngày")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(16)

                        // Nút Cài đặt
                        Button(action: onOpenSettings) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Hero Banner: Chơi Nhanh Hôm Nay
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("THỬ THÁCH HÔM NAY")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))

                                Text("Màu Sắc & Động Vật")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Text("🦊")
                                .font(.system(size: 42))
                        }

                        Text("Vượt 15 cổng từ vựng để duy trì chuỗi học và nhận huy hiệu ngày mới!")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Button(action: {
                            onSelectChallenge(.colors, .basic, .voiceRunner)
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Chơi Ngay (Voice Runner)")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.65, green: 0.93, blue: 0.15))
                            .cornerRadius(18)
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.20, blue: 0.12), Color(red: 0.10, green: 0.10, blue: 0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(red: 0.65, green: 0.93, blue: 0.15).opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // 3 Chế Độ Chơi (Game Modes)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Chế Độ Chơi")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)

                        VStack(spacing: 12) {
                            ModeCard(
                                emoji: "🏃‍♂️",
                                title: "Voice Runner",
                                tag: "Cổ Điển",
                                desc: "Mở cổng từ vựng, giúp chú cáo vượt chướng ngại vật (3 mạng).",
                                accent: Color(red: 0.65, green: 0.93, blue: 0.15)
                            ) {
                                onSelectChallenge(.colors, .basic, .voiceRunner)
                            }

                            ModeCard(
                                emoji: "👅",
                                title: "Líu Lưỡi (Tongue Twister)",
                                tag: "Luyện Âm",
                                desc: "Đọc câu dài líu lưỡi trôi chảy, không ngắt quãng quá 1.5s.",
                                accent: Color.orange
                            ) {
                                onSelectChallenge(.colors, .medium, .tongueTwister)
                            }

                            ModeCard(
                                emoji: "⚡",
                                title: "Đua Từ 30s (Category Rush)",
                                tag: "Phản Xạ",
                                desc: "Nói càng nhiều từ thuộc cùng chủ đề trong 30 giây càng tốt.",
                                accent: Color.cyan
                            ) {
                                onSelectChallenge(.animals, .basic, .categoryRush)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Danh Sách 12 Chủ Đề Khám Phá
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Chủ Đề Từ Vựng")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(Subject.allCases) { subj in
                                    Button(action: { onSelectSubject(subj) }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(subj.emoji)
                                                .font(.system(size: 32))
                                            Text(subj.titleVi)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("\(subj.learnersCount) người học")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .frame(width: 130, height: 110, alignment: .leading)
                                        .padding(14)
                                        .background(subj.cardColor.opacity(0.85))
                                        .cornerRadius(18)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
        }
    }
}

private struct ModeCard: View {
    let emoji: String
    let title: String
    let tag: String
    let desc: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 36))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(tag)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.15))
                            .cornerRadius(10)
                    }

                    Text(desc)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .cornerRadius(20)
        }
    }
}
