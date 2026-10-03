//
//  CountdownBannerView.swift
//  VoiceFilter_iOS
//
//  Component đếm ngược 3-2-1 trước khi tự động bắt đầu ghi hình.
//  Hiệu ứng phóng to scale + mờ dần kết hợp âm thanh & rung phản hồi (Haptic).
//

import SwiftUI

public struct CountdownBannerView: View {
    public let count: Int

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(displayText)
                    .font(.system(size: 110, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.8), radius: 24, x: 0, y: 0)
                    .scaleEffect(count > 0 ? 1.0 : 1.2)
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: count)

                Text(count > 0 ? "CHUẨN BỊ PHÁT ÂM..." : "BẮT ĐẦU!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(2.0)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
            }
        }
    }

    private var displayText: String {
        if count > 0 {
            return "\(count)"
        } else {
            return "GO!"
        }
    }
}
