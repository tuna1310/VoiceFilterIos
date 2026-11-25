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
                            Text("SPEAK RIGHT")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Practice pronunciation in AR with the fox")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        // Chuỗi ngày học
                        HStack(spacing: 4) {
                            Text("🔥")
                            Text("\(settings.dailyStreak) Days")
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
                                Text("TODAY'S CHALLENGE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))

                                Text("Colors & Animals")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Text("🦊")
                                .font(.system(size: 42))
                        }

                        Text("Clear 15 word gates to keep your streak and earn today's badge!")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Button(action: {
                            onSelectChallenge(.colors, .basic, .voiceRunner)
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play Now (Voice Runner)")
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
                        Text("Game Modes")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)

                        VStack(spacing: 12) {
                            ModeCard(
                                emoji: "🏃‍♂️",
                                title: "Voice Runner",
                                tag: "Classic",
                                desc: "Open word gates and help the fox clear obstacles (3 lives).",
                                accent: Color(red: 0.65, green: 0.93, blue: 0.15)
                            ) {
                                onSelectChallenge(.colors, .basic, .voiceRunner)
                            }

                            ModeCard(
                                emoji: "👅",
                                title: "Tongue Twister",
                                tag: "Pronunciation",
                                desc: "Read long tongue twisters fluently without pausing over 1.5s.",
                                accent: Color.orange
                            ) {
                                onSelectChallenge(.colors, .medium, .tongueTwister)
                            }

                            ModeCard(
                                emoji: "⚡",
                                title: "30s Category Rush",
                                tag: "Reflex",
                                desc: "Say as many words from one category as you can in 30 seconds.",
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
                            Text("Vocabulary Topics")
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
                                            Text("\(subj.learnersCount) learners")
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
