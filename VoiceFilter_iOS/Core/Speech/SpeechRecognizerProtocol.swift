//
//  SpeechRecognizerProtocol.swift
//  VoiceFilter_iOS
//
//  Interface chuẩn cho hệ thống Speech Recognition, tương thích giữa iOS và Android.
//

import Foundation
import CoreMedia

public enum SpeechRecognizerError: LocalizedError {
    case recognizerUnavailable

    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: return "Speech recognizer is unavailable."
        }
    }
}

public enum SpeechRecognizerState {
    case idle
    case listening
    case silenceTimeout // Im lặng quá ngưỡng, chờ người dùng/game kích hoạt lại
    case stopped
    case failed(Error)
}

extension SpeechRecognizerState: Equatable {
    public static func == (lhs: SpeechRecognizerState, rhs: SpeechRecognizerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.listening, .listening), (.silenceTimeout, .silenceTimeout), (.stopped, .stopped):
            return true
        case (.failed(let l), .failed(let r)):
            return l.localizedDescription == r.localizedDescription
        default:
            return false
        }
    }
}

public protocol SpeechRecognizerDelegate: AnyObject {
    /// Báo kết quả từng phần (realtime partial transcription)
    func speechRecognizer(_ recognizer: SpeechRecognizerProtocol, didRecognizePartialText text: String)

    /// Báo kết quả cuối cùng (final transcription)
    func speechRecognizer(_ recognizer: SpeechRecognizerProtocol, didRecognizeFinalText text: String)

    /// Báo lỗi trong quá trình nhận diện
    func speechRecognizer(_ recognizer: SpeechRecognizerProtocol, didEncounterError error: Error)

    /// Báo im lặng quá ngưỡng trong lượt chơi (Lỗi 1110), dừng nhận diện và chờ kích hoạt lại
    func speechRecognizerDidDetectSilenceTimeout(_ recognizer: SpeechRecognizerProtocol)

    /// Báo trạng thái khả dụng (available / unavailable)
    func speechRecognizer(_ recognizer: SpeechRecognizerProtocol, didChangeAvailability available: Bool)
}

public protocol SpeechRecognizerProtocol: AnyObject {
    var delegate: SpeechRecognizerDelegate? { get set }
    var state: SpeechRecognizerState { get }
    var isRunning: Bool { get }
    var isOnDevice: Bool { get }
    var currentLocale: Locale { get set }

    /// Bắt đầu lượt nhận diện (gắn theo vòng đời lượt chơi/từ vựng)
    func startTurn() throws

    /// Kết thúc lượt nhận diện hiện tại
    func stopTurn()

    /// Đưa sample buffer từ AVCaptureAudioDataOutput vào luồng nhận diện
    func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer)

    /// Dừng toàn bộ phiên nhận diện
    func stopRecognition()

    /// Thử lại sau khi bị timeout im lặng
    func retryAfterSilence() throws
}
