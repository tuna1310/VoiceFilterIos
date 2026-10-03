//
//  CategoryRushEvaluator.swift
//  VoiceFilter_iOS
//
//  Quản lý chế độ Đua từ 30 giây (Category Rush):
//  - Đếm ngược 30 giây
//  - Kiểm tra từ có thuộc chủ đề cho phép không
//  - Chống tính điểm từ trùng lặp
//  - Tính tổng điểm và số sao đạt được
//

import Foundation

public final class CategoryRushEvaluator {
    public static let durationSeconds: Int = 30

    private let normalizedAllowedSet: Set<String>
    private var _uniqueWordsSpoken: Set<String> = []

    public var uniqueWordsSpoken: Set<String> {
        return _uniqueWordsSpoken
    }

    public enum SubmissionResult: Equatable {
        case accepted(word: String, totalUniqueCount: Int)
        case duplicate(word: String)
        case notInSubject(word: String)
    }

    public init(allowedSubjectWords: [String]) {
        self.normalizedAllowedSet = Set(
            allowedSubjectWords
                .map { CategoryRushEvaluator.normalize($0) }
                .filter { !$0.isEmpty }
        )
    }

    public static func normalize(_ word: String) -> String {
        return word.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    public func submitWord(_ spokenWord: String) -> SubmissionResult {
        let norm = CategoryRushEvaluator.normalize(spokenWord)
        guard !norm.isEmpty else {
            return .notInSubject(word: spokenWord)
        }

        guard normalizedAllowedSet.contains(norm) else {
            return .notInSubject(word: spokenWord)
        }

        if _uniqueWordsSpoken.contains(norm) {
            return .duplicate(word: spokenWord)
        }

        _uniqueWordsSpoken.insert(norm)
        return .accepted(word: spokenWord, totalUniqueCount: _uniqueWordsSpoken.count)
    }

    public func getScore() -> Int {
        return _uniqueWordsSpoken.count * 10
    }

    public func getStars() -> Int {
        let count = _uniqueWordsSpoken.count
        if count >= 12 { return 3 }
        if count >= 6 { return 2 }
        return 1
    }

    public func reset() {
        _uniqueWordsSpoken.removeAll()
    }
}
