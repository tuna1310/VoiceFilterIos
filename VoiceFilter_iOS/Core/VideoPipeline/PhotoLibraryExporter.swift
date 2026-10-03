//
//  PhotoLibraryExporter.swift
//  VoiceFilter_iOS
//
//  Lưu video MP4 đã render vào Thư viện ảnh (Photos Album):
//  - Kiểm tra quyền PHAuthorizationStatus.
//  - Sử dụng PHPhotoLibrary.performChanges để tạo asset video.
//

import Foundation
import Photos

public final class PhotoLibraryExporter {
    public static let shared = PhotoLibraryExporter()

    private init() {}

    public func saveVideoToAlbum(fileURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            completion(.failure(PhotoExportError.fileNotFound))
            return
        }

        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if currentStatus == .authorized || currentStatus == .limited {
            self.performSave(fileURL: fileURL, completion: completion)
        } else if currentStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
                if status == .authorized || status == .limited {
                    self?.performSave(fileURL: fileURL, completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(PhotoExportError.permissionDenied))
                    }
                }
            }
        } else {
            completion(.failure(PhotoExportError.permissionDenied))
        }
    }

    private func performSave(fileURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("[PhotoLibraryExporter] Video saved successfully to Photos album!")
                    completion(.success(()))
                } else {
                    let err = error ?? PhotoExportError.saveFailed
                    print("[PhotoLibraryExporter] Save to Photos failed: \(err)")
                    completion(.failure(err))
                }
            }
        }
    }
}

public enum PhotoExportError: LocalizedError {
    case fileNotFound
    case permissionDenied
    case saveFailed

    public var errorDescription: String? {
        switch self {
        case .fileNotFound: return "Không tìm thấy file video MP4 cần lưu."
        case .permissionDenied: return "Chưa cấp quyền lưu video vào Thư viện ảnh."
        case .saveFailed: return "Lưu video vào Thư viện ảnh thất bại."
        }
    }
}
