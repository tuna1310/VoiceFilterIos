//
//  OnboardingView.swift
//  VoiceFilter_iOS
//
//  Màn hình Giới thiệu tính năng (Onboarding)
//

import SwiftUI

public struct OnboardingPage: Identifiable {
    public let id = UUID()
    let emoji: String
    let title: String
    let subtitle: String
}

public struct OnboardingView: View {
    public let onFinish: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            emoji: "🏃‍♂️",
            title: "Voice Runner",
            subtitle: "Read the English words on screen out loud to open gates before you hit the obstacles!"
        ),
        OnboardingPage(
            emoji: "👅",
            title: "Tongue Twister",
            subtitle: "Train your mouth muscles with long tongue twisters, steady breathing and smooth speech."
        ),
        OnboardingPage(
            emoji: "⚡",
            title: "30s Category Rush",
            subtitle: "Boost your reflexes: say as many words from one category as you can in 30 seconds."
        )
    ]

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 32) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        onFinish()
                    }
                    .foregroundColor(.gray)
                    .font(.system(size: 15, weight: .medium))
                    .padding()
                }

                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { idx in
                        let page = pages[idx]
                        VStack(spacing: 24) {
                            Text(page.emoji)
                                .font(.system(size: 88))
                                .padding(.bottom, 12)

                            Text(page.title)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.white)

                            Text(page.subtitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .tag(idx)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        onFinish()
                    }
                }) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.65, green: 0.93, blue: 0.15))
                        .cornerRadius(24)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
        }
    }
}
