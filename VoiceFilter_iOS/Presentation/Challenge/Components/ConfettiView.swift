//
//  ConfettiView.swift
//  VoiceFilter_iOS
//
//  Hiệu ứng pháo giấy Confetti tung bay ăn mừng khi phát âm chuẩn
//

import SwiftUI

public struct ConfettiParticle: Identifiable {
    public let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var rotation: Double
    var speedY: CGFloat
    var speedX: CGFloat
    var opacity: Double
}

public struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var timer: Timer?

    private let colors: [Color] = [
        .red, .yellow, .green, .blue, .orange, .pink, .purple,
        Color(red: 0.65, green: 0.93, blue: 0.15) // Neon lime
    ]

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { p in
                    Rectangle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 1.5)
                        .rotationEffect(.degrees(p.rotation))
                        .position(x: p.x, y: p.y)
                        .opacity(p.opacity)
                }
            }
            .onAppear {
                spawnParticles(in: geometry.size)
                startAnimation(in: geometry.size)
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
        .allowsHitTesting(false)
    }

    private func spawnParticles(in size: CGSize) {
        var newParticles: [ConfettiParticle] = []
        for _ in 0..<45 {
            let p = ConfettiParticle(
                x: CGFloat.random(in: size.width * 0.1...size.width * 0.9),
                y: CGFloat.random(in: -40...size.height * 0.2),
                size: CGFloat.random(in: 8...14),
                color: colors.randomElement() ?? .yellow,
                rotation: Double.random(in: 0...360),
                speedY: CGFloat.random(in: 4...9),
                speedX: CGFloat.random(in: -2...2),
                opacity: 1.0
            )
            newParticles.append(p)
        }
        self.particles = newParticles
    }

    private func startAnimation(in size: CGSize) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            for i in particles.indices {
                particles[i].y += particles[i].speedY
                particles[i].x += particles[i].speedX
                particles[i].rotation += 4.0
                if particles[i].y > size.height * 0.7 {
                    particles[i].opacity = max(particles[i].opacity - 0.03, 0.0)
                }
            }
        }
    }
}
