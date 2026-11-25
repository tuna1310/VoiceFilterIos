//
//  WatermarkBadgeView.swift
//  VoiceFilter_iOS
//
//  Huy hiệu Watermark bản quyền tự động đóng vào màn hình AR và video quay
//

import SwiftUI

public struct WatermarkBadgeView: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 6) {
            Text("🎙️")
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 0) {
                Text("Speak Right")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Pronunciation Challenge")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
