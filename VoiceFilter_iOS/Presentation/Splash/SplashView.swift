//
//  SplashView.swift
//  VoiceFilter_iOS
//
//  Màn hình Splash khởi động ứng dụng với hiệu ứng mượt mà
//

import SwiftUI

public struct SplashView: View {
    public let onComplete: () -> Void

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.65, green: 0.93, blue: 0.15).opacity(0.2))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)

                    Text("🦊")
                        .font(.system(size: 72))
                }
                .scaleEffect(scale)

                VStack(spacing: 6) {
                    Text("Nói Chuẩn")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Thử Thách Phát Âm")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))

                    Text("Voice Filter: Speak Challenge")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
            // Tải dữ liệu từ vựng trước khi chuyển màn hình
            VocabularyRepository.shared.loadWords()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                onComplete()
            }
        }
    }
}
