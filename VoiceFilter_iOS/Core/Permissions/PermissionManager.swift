//
//  PermissionManager.swift
//  VoiceFilter_iOS
//
//  Quản lý trạng thái và yêu cầu quyền hệ thống:
//  - Camera (AVCaptureDevice)
//  - Microphone (AVCaptureDevice)
//  - Speech Recognition (SFSpeechRecognizer)
//  - Photo Library Add Only (PHPhotoLibrary)
//  - Hướng dẫn mở Settings khi bị người dùng từ chối.
//

import Foundation
import AVFoundation
import Speech
import Photos
import UIKit

public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published public var microphoneStatus: AVAuthorizationStatus = .notDetermined
    @Published public var speechStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published public var photoLibraryStatus: PHAuthorizationStatus = .notDetermined

    public var hasCorePermissions: Bool {
        return isCameraAuthorized && isMicrophoneAuthorized && isSpeechAuthorized
    }

    public var isCameraAuthorized: Bool {
        return cameraStatus == .authorized
    }

    public var isMicrophoneAuthorized: Bool {
        return microphoneStatus == .authorized
    }

    public var isSpeechAuthorized: Bool {
        return speechStatus == .authorized
    }

    public var isPhotoLibraryAuthorized: Bool {
        return photoLibraryStatus == .authorized || photoLibraryStatus == .limited
    }

    public var isAnyCorePermissionDenied: Bool {
        return cameraStatus == .denied || cameraStatus == .restricted ||
               microphoneStatus == .denied || microphoneStatus == .restricted ||
               speechStatus == .denied || speechStatus == .restricted
    }

    private init() {
        checkAllPermissions()
    }

    /// Kiểm tra trạng thái hiện tại của toàn bộ quyền
    public func checkAllPermissions() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        speechStatus = SFSpeechRecognizer.authorizationStatus()
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }

    /// Yêu cầu cấp quyền Camera
    public func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                completion(granted)
            }
        }
    }

    /// Yêu cầu cấp quyền Microphone
    public func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                completion(granted)
            }
        }
    }

    /// Yêu cầu cấp quyền Speech Recognition
    public func requestSpeechPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.speechStatus = status
                completion(status == .authorized)
            }
        }
    }

    /// Yêu cầu cấp quyền Thư viện ảnh (để lưu video)
    public func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                self?.photoLibraryStatus = status
                completion(status == .authorized || status == .limited)
            }
        }
    }

    /// Yêu cầu liên tiếp 3 quyền cốt lõi (Camera -> Mic -> Speech)
    public func requestAllCorePermissions(completion: @escaping (Bool) -> Void) {
        requestCameraPermission { [weak self] camOk in
            guard let self = self else { return }
            self.requestMicrophonePermission { micOk in
                self.requestSpeechPermission { speechOk in
                    DispatchQueue.main.async {
                        self.checkAllPermissions()
                        completion(camOk && micOk && speechOk)
                    }
                }
            }
        }
    }

    /// Mở ứng dụng Settings của hệ thống
    public func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsURL) else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }
}
