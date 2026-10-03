//
//  CameraManager.swift
//  VoiceFilter_iOS
//
//  Quản lý AVCaptureSession, cung cấp:
//  - Camera trước, khung dọc 9:16 (1080x1920 hoặc 720x1280).
//  - Lật gương mặt selfie (videoMirrored = true).
//  - Điều phối đồng thời luồng Audio tới CẢ VideoRecorder VÀ SFSpeechRecognizer
//    mà KHÔNG xung đột mic và không cần AVAudioEngine tap!
//

import Foundation
import AVFoundation
import UIKit

public final class CameraManager: NSObject {
    public let captureSession = AVCaptureSession()
    public private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    public weak var speechRecognizer: SpeechRecognizerProtocol?
    public var videoRecorder: VideoRecorder?

    private let sessionQueue = DispatchQueue(label: "com.voicefilter.camera.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.voicefilter.camera.videoOutputQueue", qos: .userInteractive)
    private let audioOutputQueue = DispatchQueue(label: "com.voicefilter.camera.audioOutputQueue", qos: .userInteractive)

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()

    public private(set) var isSessionRunning = false
    public var currentCameraPosition: AVCaptureDevice.Position = .front

    public override init() {
        super.init()
    }

    /// Khởi tạo camera session và preview layer
    public func setupSession(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                // 1. Cấu hình Audio Session tập trung trước
                try AudioSessionManager.shared.configureForRecordingAndSpeech()

                self.captureSession.beginConfiguration()

                // Cố gắng đặt preset 1080x1920 (Full HD), fallback 720x1280 hoặc High
                if self.captureSession.canSetSessionPreset(.hd1920x1080) {
                    self.captureSession.sessionPreset = .hd1920x1080
                } else if self.captureSession.canSetSessionPreset(.hd1280x720) {
                    self.captureSession.sessionPreset = .hd1280x720
                } else {
                    self.captureSession.sessionPreset = .high
                }

                // 2. Thêm Video Input (Mặc định Camera trước)
                try self.addVideoInput(position: self.currentCameraPosition)

                // 3. Thêm Audio Input (Microphone)
                try self.addAudioInput()

                // 4. Cấu hình Video Output
                if self.captureSession.canAddOutput(self.videoOutput) {
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                    ]
                    self.videoOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
                    self.captureSession.addOutput(self.videoOutput)

                    if let connection = self.videoOutput.connection(with: .video) {
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                        if connection.isVideoMirroringSupported && self.currentCameraPosition == .front {
                            connection.isVideoMirrored = true
                        }
                    }
                } else {
                    throw CameraManagerError.cannotAddVideoOutput
                }

                // 5. Cấu hình Audio Output
                if self.captureSession.canAddOutput(self.audioOutput) {
                    self.audioOutput.setSampleBufferDelegate(self, queue: self.audioOutputQueue)
                    self.captureSession.addOutput(self.audioOutput)
                } else {
                    throw CameraManagerError.cannotAddAudioOutput
                }

                self.captureSession.commitConfiguration()

                // Tạo Preview Layer
                DispatchQueue.main.async {
                    let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
                    preview.videoGravity = .resizeAspectFill
                    if preview.connection?.isVideoOrientationSupported == true {
                        preview.connection?.videoOrientation = .portrait
                    }
                    self.previewLayer = preview
                    completion(.success(()))
                }
            } catch {
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            self.isSessionRunning = self.captureSession.isRunning
            print("[CameraManager] Capture session started.")
        }
    }

    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            self.isSessionRunning = false
            print("[CameraManager] Capture session stopped.")
        }
    }

    public func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()

            let newPosition: AVCaptureDevice.Position = (self.currentCameraPosition == .front) ? .back : .front

            if let currentInput = self.videoInput {
                self.captureSession.removeInput(currentInput)
            }

            do {
                try self.addVideoInput(position: newPosition)
                self.currentCameraPosition = newPosition

                if let connection = self.videoOutput.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = (newPosition == .front)
                    }
                }
            } catch {
                print("[CameraManager] Switch camera failed: \(error.localizedDescription)")
            }

            self.captureSession.commitConfiguration()
        }
    }

    // MARK: - Helper Methods

    private func addVideoInput(position: AVCaptureDevice.Position) throws {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: position
        )

        guard let device = discoverySession.devices.first else {
            throw CameraManagerError.cameraDeviceNotFound
        }

        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            self.videoInput = input
        } else {
            throw CameraManagerError.cannotAddVideoInput
        }
    }

    private func addAudioInput() throws {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw CameraManagerError.audioDeviceNotFound
        }

        let input = try AVCaptureDeviceInput(device: audioDevice)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            self.audioInput = input
        } else {
            throw CameraManagerError.cannotAddAudioInput
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoOutput {
            // 1. Gửi video frame tới VideoRecorder
            videoRecorder?.appendVideoSampleBuffer(sampleBuffer)
        } else if output == audioOutput {
            // 2. Gửi audio frame đồng thời tới:
            //    - VideoRecorder (để xuất file MP4 có tiếng)
            //    - SpeechRecognizer (để nhận diện giọng nói realtime)
            videoRecorder?.appendAudioSampleBuffer(sampleBuffer)
            speechRecognizer?.appendAudioSampleBuffer(sampleBuffer)
        }
    }
}

public enum CameraManagerError: LocalizedError {
    case cameraDeviceNotFound
    case audioDeviceNotFound
    case cannotAddVideoInput
    case cannotAddAudioInput
    case cannotAddVideoOutput
    case cannotAddAudioOutput

    public var errorDescription: String? {
        switch self {
        case .cameraDeviceNotFound: return "Không tìm thấy thiết bị Camera trên máy."
        case .audioDeviceNotFound: return "Không tìm thấy thiết bị Microphone."
        case .cannotAddVideoInput: return "Không thể kết nối video camera vào phiên làm việc."
        case .cannotAddAudioInput: return "Không thể kết nối audio mic vào phiên làm việc."
        case .cannotAddVideoOutput: return "Không thể thiết lập cổng xuất video."
        case .cannotAddAudioOutput: return "Không thể thiết lập cổng xuất audio."
        }
    }
}
