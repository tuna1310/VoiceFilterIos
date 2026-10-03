//
//  VideoRecorder.swift
//  VoiceFilter_iOS
//
//  Ghi hình video 9:16 thời gian thực từ AVCaptureSession bằng AVAssetWriter:
//  - Codec Video: H.264, độ phân giải 1080x1920 (fallback 720x1280).
//  - Codec Audio: AAC, 44.1kHz.
//  - Đồng bộ timestamp video và audio, đảm bảo thời lượng chính xác.
//

import Foundation
import AVFoundation

public final class VideoRecorder {
    public enum RecorderState {
        case idle
        case recording
        case finishing
    }

    public private(set) var state: RecorderState = .idle
    public private(set) var outputURL: URL?

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?

    private let writerQueue = DispatchQueue(label: "com.voicefilter.video.writerQueue", qos: .userInitiated)
    private var sessionStartTime: CMTime?
    private var isSessionStarted = false

    private let targetWidth: Int
    private let targetHeight: Int

    public init(width: Int = 1080, height: Int = 1920) {
        self.targetWidth = width
        self.targetHeight = height
    }

    /// Bắt đầu phiên ghi hình ra file MP4 tạm thời
    public func startRecording() throws -> URL {
        return try writerQueue.sync {
            guard state == .idle else {
                throw VideoRecorderError.alreadyRecording
            }

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "VoiceFilter_\(UUID().uuidString).mp4"
            let fileURL = tempDir.appendingPathComponent(fileName)

            // Xóa file cũ nếu vô tình trùng tên
            try? FileManager.default.removeItem(at: fileURL)

            let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)

            // 1. Cấu hình Video Input (H.264, 1080x1920 Portrait 9:16)
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: targetWidth,
                AVVideoHeightKey: targetHeight,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 8_000_000, // 8 Mbps chất lượng cao
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoExpectedSourceFrameRateKey: 30
                ]
            ]
            let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            vInput.expectsMediaDataInRealTime = true
            vInput.transform = CGAffineTransform.identity // Orientation đã được xoay đúng từ AVCaptureConnection

            if writer.canAdd(vInput) {
                writer.add(vInput)
            } else {
                throw VideoRecorderError.cannotAddVideoInput
            }

            // 2. Cấu hình Audio Input (AAC 44.1kHz Stereo)
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100.0,
                AVEncoderBitRateKey: 128_000
            ]
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true

            if writer.canAdd(aInput) {
                writer.add(aInput)
            } else {
                throw VideoRecorderError.cannotAddAudioInput
            }

            guard writer.startWriting() else {
                throw writer.error ?? VideoRecorderError.writerFailedToStart
            }

            self.assetWriter = writer
            self.videoInput = vInput
            self.audioInput = aInput
            self.outputURL = fileURL
            self.sessionStartTime = nil
            self.isSessionStarted = false
            self.state = .recording

            print("[VideoRecorder] Recording started at: \(fileURL.path)")
            return fileURL
        }
    }

    /// Đưa video frame vào asset writer
    public func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        writerQueue.async { [weak self] in
            guard let self = self, self.state == .recording, let writer = self.assetWriter, let vInput = self.videoInput else {
                return
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if !self.isSessionStarted {
                writer.startSession(atSourceTime: presentationTime)
                self.sessionStartTime = presentationTime
                self.isSessionStarted = true
                print("[VideoRecorder] Writer session initialized at timestamp: \(presentationTime.seconds)s")
            }

            if vInput.isReadyForMoreMediaData {
                if !vInput.append(sampleBuffer) {
                    print("[VideoRecorder] Failed to append video buffer: \(String(describing: writer.error))")
                }
            }
        }
    }

    /// Đưa audio frame vào asset writer
    public func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        writerQueue.async { [weak self] in
            guard let self = self, self.state == .recording, self.isSessionStarted, let writer = self.assetWriter, let aInput = self.audioInput else {
                return
            }

            if aInput.isReadyForMoreMediaData {
                if !aInput.append(sampleBuffer) {
                    print("[VideoRecorder] Failed to append audio buffer: \(String(describing: writer.error))")
                }
            }
        }
    }

    /// Dừng ghi hình và hoàn tất file MP4
    public func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        writerQueue.async { [weak self] in
            guard let self = self, self.state == .recording, let writer = self.assetWriter, let outputURL = self.outputURL else {
                DispatchQueue.main.async {
                    completion(.failure(VideoRecorderError.notRecording))
                }
                return
            }

            self.state = .finishing

            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()

            writer.finishWriting {
                DispatchQueue.main.async {
                    if writer.status == .completed {
                        print("[VideoRecorder] Export MP4 completed successfully: \(outputURL.path)")
                        self.state = .idle
                        completion(.success(outputURL))
                    } else {
                        let err = writer.error ?? VideoRecorderError.writerFailedToFinish
                        print("[VideoRecorder] Finish writing failed: \(err)")
                        self.state = .idle
                        completion(.failure(err))
                    }
                }
            }
        }
    }

    /// Hủy bỏ phiên ghi hình đang chạy (không lưu file)
    public func cancelRecording() {
        writerQueue.async { [weak self] in
            guard let self = self, self.state != .idle else { return }
            self.assetWriter?.cancelWriting()
            if let outputURL = self.outputURL {
                try? FileManager.default.removeItem(at: outputURL)
            }
            self.state = .idle
            self.outputURL = nil
            print("[VideoRecorder] Recording canceled and temp file purged.")
        }
    }
}

public enum VideoRecorderError: LocalizedError {
    case alreadyRecording
    case notRecording
    case cannotAddVideoInput
    case cannotAddAudioInput
    case writerFailedToStart
    case writerFailedToFinish

    public var errorDescription: String? {
        switch self {
        case .alreadyRecording: return "Đang có phiên ghi hình khác hoạt động."
        case .notRecording: return "Không có phiên ghi hình nào đang chạy."
        case .cannotAddVideoInput: return "Không thể thêm track video vào bộ ghi file."
        case .cannotAddAudioInput: return "Không thể thêm track audio vào bộ ghi file."
        case .writerFailedToStart: return "Không thể khởi động bộ ghi AVAssetWriter."
        case .writerFailedToFinish: return "Bộ ghi file gặp lỗi khi xuất MP4 hoàn chỉnh."
        }
    }
}
