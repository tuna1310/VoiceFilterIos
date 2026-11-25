//
//  SubjectsView.swift
//  VoiceFilter_iOS
//
//  Màn hình Danh sách 12 Chủ đề từ vựng (SubjectsScreen):
//  - Lưới 2 cột các chủ đề với màu sắc và số lượng người học
//  - Thanh tìm kiếm từ vựng trên toàn bộ 600 từ
//

import SwiftUI

public struct SubjectsView: View {
    public let onSelectSubject: (Subject) -> Void
    public let onBack: () -> Void

    @State private var searchQuery = ""
    @ObservedObject private var vocabRepo = VocabularyRepository.shared

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    public init(onSelectSubject: @escaping (Subject) -> Void, onBack: @escaping () -> Void) {
        self.onSelectSubject = onSelectSubject
        self.onBack = onBack
    }

    public var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 16) {
                // Header Bar
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }

                    Text("Vocabulary Topics")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search words, phonetics...", text: $searchQuery)
                        .foregroundColor(.white)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                .cornerRadius(16)
                .padding(.horizontal, 20)

                ScrollView(showsIndicators: false) {
                    if searchQuery.isEmpty {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(Subject.allCases) { subj in
                                Button(action: { onSelectSubject(subj) }) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(subj.emoji)
                                                .font(.system(size: 32))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white.opacity(0.5))
                                        }

                                        Text(subj.titleVi)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)

                                        Text("\(subj.learnersCount) learners")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(subj.cardColor.opacity(0.85))
                                    .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        // Kết quả tìm kiếm
                        let searchResults = vocabRepo.search(query: searchQuery)
                        LazyVStack(spacing: 10) {
                            ForEach(searchResults) { word in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(word.word)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(word.phonetic)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
                                        Text(word.tip)
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(word.level.displayName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .padding(14)
                                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}
