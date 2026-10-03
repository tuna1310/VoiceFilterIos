//
//  PermissionRequestView.swift
//  VoiceFilter_iOS
//
//  Màn hình xin quyền Camera, Microphone và Speech Recognition:
//  - Thiết kế Glassmorphism hiện đại theo phong cách TikTok/Reels.
//  - Hiển thị rõ trạng thái từng quyền và hướng dẫn mở Cài đặt nếu bị từ chối.
//

import SwiftUI
import AVFoundation
import Speech

public struct PermissionRequestView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    public var onPermissionsGranted: () -> Void

    public init(onPermissionsGranted: @escaping () -> Void) {
        self.onPermissionsGranted = onPermissionsGranted
    }

    public var body: some View {
        ZStack {
            // Nền Gradient tối sang trọng
            LinearGradient(
                colors: [Color(hex: "0D1117"), Color(hex: "161B22"), Color(hex: "090D16")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Header & Icon
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)

                        Image(systemName: "mic.badge.waveform")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    Text("Voice Filter: Speak Challenge")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Để bắt đầu thử thách phát âm bằng camera filter vui nhộn, ứng dụng cần một số quyền truy cập:")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Danh sách các quyền
                VStack(spacing: 14) {
                    permissionRow(
                        icon: "camera.fill",
                        title: "Camera trước",
                        desc: "Hiển thị khuôn mặt bạn cùng hiệu ứng đường chạy 3D và ghi video.",
                        isAuthorized: permissionManager.isCameraAuthorized,
                        isDenied: permissionManager.cameraStatus == .denied
                    )

                    permissionRow(
                        icon: "mic.fill",
                        title: "Microphone",
                        desc: "Ghi âm giọng đọc tiếng Anh của bạn và lưu vào video.",
                        isAuthorized: permissionManager.isMicrophoneAuthorized,
                        isDenied: permissionManager.microphoneStatus == .denied
                    )

                    permissionRow(
                        icon: "waveform.badge.magnifyingglass",
                        title: "Nhận diện giọng nói",
                        desc: "Chấm điểm và nhận diện từ vựng on-device không cần gửi ra ngoài.",
                        isAuthorized: permissionManager.isSpeechAuthorized,
                        isDenied: permissionManager.speechStatus == .denied
                    )
                }
                .padding(.horizontal, 20)

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    if permissionManager.isAnyCorePermissionDenied {
                        Button(action: {
                            permissionManager.openAppSettings()
                        }) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Mở Cài đặt hệ thống")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .orange.opacity(0.3), radius: 10, y: 5)
                        }

                        Text("Một hoặc nhiều quyền đã bị từ chối trước đó. Vui lòng bật lại trong Cài đặt để tiếp tục.")
                            .font(.caption)
                            .foregroundColor(.orange.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    } else {
                        Button(action: {
                            permissionManager.requestAllCorePermissions { granted in
                                if granted {
                                    onPermissionsGranted()
                                }
                            }
                        }) {
                            HStack {
                                Text("Cấp quyền & Bắt đầu")
                                    .fontWeight(.bold)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.4), radius: 12, y: 6)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            permissionManager.checkAllPermissions()
        }
    }

    private func permissionRow(icon: String, title: String, desc: String, isAuthorized: Bool, isDenied: Bool) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(isAuthorized ? .green : (isDenied ? .red : .blue))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isAuthorized ? Color.green.opacity(0.15) : (isDenied ? Color.red.opacity(0.15) : Color.blue.opacity(0.15)))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()

            if isAuthorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            } else if isDenied {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 20))
            } else {
                Text("Cần cấp")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
