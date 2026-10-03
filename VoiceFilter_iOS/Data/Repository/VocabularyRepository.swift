//
//  VocabularyRepository.swift
//  VoiceFilter_iOS
//
//  Quản lý toàn bộ 600 từ vựng và câu luyện phát âm:
//  - Tải từ vựng từ bộ nhớ cache cục bộ hoặc words.json trong Bundle
//  - Đồng bộ từ xa từ Supabase Cloud / Remote Config không cần cập nhật lại app trên App Store
//  - Lưu cache offline vào Application Support
//  - Hỗ trợ lọc theo Chủ đề, Cấp độ khó, Chế độ chơi và Bookmark
//

import Foundation
import Combine

public final class VocabularyRepository: ObservableObject {
    public static let shared = VocabularyRepository()

    @Published public private(set) var allWords: [WordItem] = []
    @Published public private(set) var isLoaded: Bool = false
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncDate: Date? = nil
    @Published public private(set) var syncErrorMessage: String? = nil
    @Published public private(set) var bookmarkedIds: Set<String> = []

    private let bookmarkKey = "noichuan_bookmarked_words"
    private let lastSyncKey = "noichuan_last_remote_sync_date"

    private var cacheFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("VoiceFilter_Cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("words_cached.json")
    }

    public init() {
        loadBookmarks()
        loadLastSyncDate()
        loadWords()
        // Tự động kiểm tra cập nhật ngầm từ Supabase / Remote Config
        syncRemoteVocabulary(completion: nil)
    }

    // MARK: - Load Words (Cache First -> Bundle Fallback)

    /// Tải dữ liệu từ words_cached.json (nếu có) hoặc words.json trong Bundle
    public func loadWords() {
        // 1. Thử tải từ File Cache đã đồng bộ trước đó
        if FileManager.default.fileExists(atPath: cacheFileURL.path) {
            do {
                let cachedData = try Data(contentsOf: cacheFileURL)
                let items = try JSONDecoder().decode([WordItem].self, from: cachedData)
                if !items.isEmpty {
                    DispatchQueue.main.async {
                        self.allWords = items
                        self.isLoaded = true
                        print("[VocabularyRepository] Đã nạp \(items.count) từ từ file Cache offline!")
                    }
                    return
                }
            } catch {
                print("[VocabularyRepository] Đọc file cache thất bại, chuyển sang file Bundle: \(error)")
            }
        }

        // 2. Tìm file trong Bundle (hoặc subpath SeedData)
        var url = Bundle.main.url(forResource: "words", withExtension: "json")
        if url == nil {
            url = Bundle.main.url(forResource: "words", withExtension: "json", subdirectory: "SeedData")
        }
        if url == nil {
            url = Bundle.module.url(forResource: "words", withExtension: "json")
        }
        if url == nil {
            // Fallback: Tìm qua file URL trực tiếp nếu đang chạy chế độ preview/test
            let currentDir = FileManager.default.currentDirectoryPath
            let fallbackPath = "\(currentDir)/VoiceFilter_iOS/Resources/SeedData/words.json"
            if FileManager.default.fileExists(atPath: fallbackPath) {
                url = URL(fileURLWithPath: fallbackPath)
            }
        }

        guard let fileURL = url else {
            print("[VocabularyRepository] Không tìm thấy file words.json trong bundle")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let items = try JSONDecoder().decode([WordItem].self, from: data)
            DispatchQueue.main.async {
                self.allWords = items
                self.isLoaded = true
                print("[VocabularyRepository] Đã nạp thành công \(items.count) từ vựng từ Seed Bundle!")
            }
        } catch {
            print("[VocabularyRepository] Lỗi giải mã words.json: \(error)")
        }
    }

    // MARK: - Remote Config & Supabase Cloud Sync

    /// Đồng bộ bộ từ vựng mới nhất từ Supabase Cloud mà không cần cập nhật app
    public func syncRemoteVocabulary(completion: ((Bool, String?) -> Void)? = nil) {
        let baseURL = AppConfiguration.supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let anonKey = AppConfiguration.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // Nếu URL vẫn là placeholder mặc định thì bỏ qua đồng bộ cloud an toàn
        guard !baseURL.contains("your-project.supabase.co") && !anonKey.contains("placeholder-key") else {
            completion?(false, "Chưa thiết lập URL và API Key Supabase hợp lệ.")
            return
        }

        guard let url = URL(string: "\(baseURL)/rest/v1/words?select=*") else {
            completion?(false, "URL endpoint Supabase không hợp lệ.")
            return
        }

        DispatchQueue.main.async {
            self.isSyncing = true
            self.syncErrorMessage = nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isSyncing = false
            }

            if let error = error {
                let msg = "Lỗi kết nối máy chủ Supabase: \(error.localizedDescription)"
                DispatchQueue.main.async {
                    self.syncErrorMessage = msg
                    completion?(false, msg)
                }
                return
            }

            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode), let data = data else {
                let msg = "Máy chủ trả về mã lỗi HTTP: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                DispatchQueue.main.async {
                    self.syncErrorMessage = msg
                    completion?(false, msg)
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let remoteWords = try decoder.decode([WordItem].self, from: data)

                guard !remoteWords.isEmpty else {
                    let msg = "Dữ liệu trả về từ Supabase rỗng."
                    DispatchQueue.main.async { completion?(false, msg) }
                    return
                }

                // Lưu vào cache cục bộ
                try data.write(to: self.cacheFileURL, options: .atomic)

                DispatchQueue.main.async {
                    self.allWords = remoteWords
                    self.lastSyncDate = Date()
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastSyncKey)
                    print("[VocabularyRepository] Đồng bộ thành công \(remoteWords.count) từ từ Supabase!")
                    completion?(true, nil)
                }
            } catch {
                let msg = "Lỗi giải mã cấu trúc từ vựng Supabase: \(error.localizedDescription)"
                DispatchQueue.main.async {
                    self.syncErrorMessage = msg
                    completion?(false, msg)
                }
            }
        }.resume()
    }

    private func loadLastSyncDate() {
        let ts = UserDefaults.standard.double(forKey: lastSyncKey)
        if ts > 0 {
            lastSyncDate = Date(timeIntervalSince1970: ts)
        }
    }

    // MARK: - Query Methods

    /// Lấy danh sách từ theo chủ đề và cấp độ khó
    public func getWords(for subject: Subject, difficulty: DifficultyLevel? = nil, gameMode: GameModeType? = nil) -> [WordItem] {
        return allWords.filter { item in
            let matchSubject = item.subject.lowercased() == subject.rawValue.lowercased()
            let matchDifficulty = (difficulty == nil) || (item.level == difficulty)
            let matchGameMode = (gameMode == nil) || (item.gameMode == gameMode)
            return matchSubject && matchDifficulty && matchGameMode
        }
    }

    /// Lấy tất cả từ vựng theo chủ đề (bất kể độ khó)
    public func getAllWords(for subject: Subject) -> [WordItem] {
        return allWords.filter { $0.subject.lowercased() == subject.rawValue.lowercased() }
    }

    /// Lấy danh sách câu cho chế độ Tongue Twister
    public func getTongueTwisters(difficulty: DifficultyLevel? = nil) -> [WordItem] {
        return allWords.filter { item in
            let isTongueTwister = item.gameMode == .tongueTwister || item.subject.lowercased() == "tongue_twister"
            let matchDifficulty = (difficulty == nil) || (item.level == difficulty)
            return isTongueTwister && matchDifficulty
        }
    }

    /// Lấy từ vựng cho Category Rush (30s)
    public func getCategoryRushWords(for subject: Subject) -> [WordItem] {
        let words = allWords.filter { $0.subject.lowercased() == subject.rawValue.lowercased() }
        return words.shuffled()
    }

    /// Tìm kiếm từ vựng theo từ khóa hoặc phiên âm
    public func search(query: String) -> [WordItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allWords }
        return allWords.filter {
            $0.word.lowercased().contains(q) ||
            $0.phonetic.lowercased().contains(q) ||
            $0.tip.lowercased().contains(q)
        }
    }

    // MARK: - Bookmarks

    private func loadBookmarks() {
        if let saved = UserDefaults.standard.stringArray(forKey: bookmarkKey) {
            bookmarkedIds = Set(saved)
        }
    }

    public func toggleBookmark(wordId: String) {
        if bookmarkedIds.contains(wordId) {
            bookmarkedIds.remove(wordId)
        } else {
            bookmarkedIds.insert(wordId)
        }
        UserDefaults.standard.set(Array(bookmarkedIds), forKey: bookmarkKey)
    }

    public func isBookmarked(wordId: String) -> Bool {
        return bookmarkedIds.contains(wordId)
    }
}
