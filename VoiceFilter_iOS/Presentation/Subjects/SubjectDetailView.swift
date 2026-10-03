//
//  SubjectDetailView.swift
//  VoiceFilter_iOS
//
//  Màn hình Chi Tiết Chủ Đề (SubjectDetailScreen):
//  - Header chủ đề với dải màu gradient và số người học
//  - Bộ chọn 3 Cấp độ khó: Dễ (Basic) / Vừa (Medium) / Khó (Advanced)
//  - Danh sách từ vựng chi tiết kèm phiên âm IPA & Mẹo phát âm tiếng Việt
//  - Nút Bookmark yêu thích
//  - Nút Bắt đầu Thử Thách AR
//

import SwiftUI

public struct SubjectDetailView: View {
    public let subject: Subject
    public let onStartChallenge: (Subject, DifficultyLevel, GameModeType) -> Void
    public let onBack: () -> Void

    @State private var selectedDifficulty: DifficultyLevel = .basic
    @State private var selectedGameMode: GameModeType = .voiceRunner
    @ObservedObject private var vocabRepo = VocabularyRepository.shared

    public init(
        subject: Subject,
        onStartChallenge: @escaping (Subject, DifficultyLevel, GameModeType) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.subject = subject
        self.onStartChallenge = onStartChallenge
        self.onBack = onBack
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header Banner
                    headerBanner

                    // Bộ Chọn Cấp Độ Khó
                    difficultyPicker

                    // Bộ Chọn Chế Độ Chơi
                    gameModePicker

                    // Danh Sách Từ Vựng Xem Trước
                    wordsPreviewList

                    Spacer(minLength: 100)
                }
            }

            // Nút Bắt Đầu Thử Thách Cố Định Dưới Đáy
            bottomCTAButton
        }
    }

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(subject.emoji)
                        .font(.system(size: 40))

                    Text(subject.titleVi)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(subject.titleEn) • \(subject.learnersCount) người luyện tập")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [subject.cardColor, subject.accentColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var difficultyPicker: some View {
        HStack(spacing: 8) {
            ForEach(DifficultyLevel.allCases) { diff in
                Button(action: {
                    withAnimation { selectedDifficulty = diff }
                }) {
                    Text(diff.displayName)
                        .font(.system(size: 13, weight: selectedDifficulty == diff ? .bold : .medium))
                        .foregroundColor(selectedDifficulty == diff ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedDifficulty == diff ? Color(red: 0.65, green: 0.93, blue: 0.15) : Color(red: 0.14, green: 0.14, blue: 0.16))
                        .cornerRadius(14)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var gameModePicker: some View {
        HStack(spacing: 8) {
            ForEach(GameModeType.allCases) { mode in
                Button(action: {
                    withAnimation { selectedGameMode = mode }
                }) {
                    HStack(spacing: 4) {
                        Text(mode.emoji)
                        Text(mode.titleEn)
                            .font(.system(size: 12, weight: selectedGameMode == mode ? .bold : .medium))
                    }
                    .foregroundColor(selectedGameMode == mode ? .black : .white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedGameMode == mode ? Color.white : Color(red: 0.12, green: 0.12, blue: 0.14))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var wordsPreviewList: some View {
        let words = vocabRepo.getWords(for: subject, difficulty: selectedDifficulty)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Danh Sách Từ Vựng (\(words.count) từ)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)

            LazyVStack(spacing: 10) {
                ForEach(words) { item in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.word)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(item.phonetic)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
                            }
                            if !item.tip.isEmpty {
                                Text(item.tip)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Button(action: {
                            vocabRepo.toggleBookmark(wordId: item.id)
                        }) {
                            Image(systemName: vocabRepo.isBookmarked(wordId: item.id) ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 16))
                                .foregroundColor(vocabRepo.isBookmarked(wordId: item.id) ? Color(red: 0.65, green: 0.93, blue: 0.15) : .gray)
                        }
                    }
                    .padding(14)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var bottomCTAButton: some View {
        VStack {
            Button(action: {
                onStartChallenge(subject, selectedDifficulty, selectedGameMode)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Bắt Đầu Thử Thách AR")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.65, green: 0.93, blue: 0.15))
                .cornerRadius(24)
                .shadow(color: Color(red: 0.65, green: 0.93, blue: 0.15).opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.0), Color(red: 0.07, green: 0.07, blue: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
