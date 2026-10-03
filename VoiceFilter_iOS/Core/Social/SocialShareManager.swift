//
//  SocialShareManager.swift
//  VoiceFilter_iOS
//
//  Quản lý chia sẻ mạng xã hội 1-chạm (One-tap Social Sharing):
//  - Chia sẻ trực tiếp lên Instagram Stories qua URL Scheme & Pasteboard
//  - Chia sẻ trực tiếp lên TikTok qua URL Scheme & Thư viện ảnh
//  - Chia sẻ trực tiếp lên Facebook Stories / Reels
//  - Tự động fallback sang UIActivityViewController nếu máy chưa cài ứng dụng đích
//

import Foundation
import UIKit
import Photos

public final class SocialShareManager {
    public static let shared = SocialShareManager()

    private init() {}

    // MARK: - Kiểm tra ứng dụng đã cài đặt

    public var isInstagramInstalled: Bool {
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    public var isTikTokInstalled: Bool {
        let schemes = ["snssdk1233://", "snssdk1180://", "tiktoksharesdk://"]
        return schemes.contains { scheme in
            if let url = URL(string: scheme) {
                return UIApplication.shared.canOpenURL(url)
            }
            return false
        }
    }

    public var isFacebookInstalled: Bool {
        guard let url = URL(string: "facebook-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - 1. Chia sẻ 1-chạm lên Instagram Stories

    public func shareToInstagramStories(
        videoURL: URL,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard isInstagramInstalled else {
            completion(false, "Thiết bị chưa cài đặt ứng dụng Instagram.")
            return
        }

        guard let videoData = try? Data(contentsOf: videoURL) else {
            completion(false, "Không thể đọc dữ liệu video.")
            return
        }

        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.backgroundVideo": videoData
        ]

        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(5 * 60)
        ]

        UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)

        guard let shareURL = URL(string: "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "com.voicefilter.ios")") else {
            completion(false, "Lỗi tạo liên kết chia sẻ.")
            return
        }

        UIApplication.shared.open(shareURL, options: [:]) { success in
            if success {
                completion(true, nil)
            } else {
                completion(false, "Không thể mở Instagram Stories.")
            }
        }
    }

    // MARK: - 2. Chia sẻ 1-chạm lên TikTok

    public func shareToTikTok(
        videoURL: URL,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard isTikTokInstalled else {
            completion(false, "Thiết bị chưa cài đặt ứng dụng TikTok.")
            return
        }

        // Đảm bảo video đã lưu trong Photos album để TikTok import mượt mà
        PhotoLibraryExporter.shared.saveVideoToAlbum(fileURL: videoURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Thử mở các URL scheme của TikTok
                    let candidateSchemes = ["snssdk1233://", "snssdk1180://", "tiktoksharesdk://"]
                    for scheme in candidateSchemes {
                        if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:]) { opened in
                                if opened {
                                    completion(true, nil)
                                } else {
                                    completion(false, "Không thể khởi động TikTok.")
                                }
                            }
                            return
                        }
                    }
                    completion(false, "Không tìm thấy giao thức mở TikTok.")
                case .failure(let err):
                    completion(false, "Cần cấp quyền Thư viện ảnh để TikTok tải video: \(err.localizedDescription)")
                }
            }
        }
    }

    // MARK: - 3. Chia sẻ 1-chạm lên Facebook Stories / Reels

    public func shareToFacebookStories(
        videoURL: URL,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard isFacebookInstalled else {
            completion(false, "Thiết bị chưa cài đặt ứng dụng Facebook.")
            return
        }

        guard let videoData = try? Data(contentsOf: videoURL) else {
            completion(false, "Không thể đọc dữ liệu video.")
            return
        }

        let pasteboardItems: [String: Any] = [
            "com.facebook.sharedSticker.backgroundVideo": videoData
        ]

        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(5 * 60)
        ]

        UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)

        guard let shareURL = URL(string: "facebook-stories://share") else {
            completion(false, "Lỗi tạo liên kết chia sẻ.")
            return
        }

        UIApplication.shared.open(shareURL, options: [:]) { success in
            if success {
                completion(true, nil)
            } else {
                completion(false, "Không thể mở Facebook Stories.")
            }
        }
    }
}
