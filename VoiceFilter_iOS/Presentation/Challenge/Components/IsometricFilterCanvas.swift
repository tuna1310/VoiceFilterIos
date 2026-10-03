//
//  IsometricFilterCanvas.swift
//  VoiceFilter_iOS
//
//  Hiệu ứng Game AR Filter Isometric 3D vẽ bằng SwiftUI Canvas:
//  - Đường chạy Isometric nghiêng 40 độ màu xanh chanh neon (Lime Green) với viền F1
//  - Linh vật chú cáo khối lập phương 3D (Low-poly Cube Fox) nhấp nhô chạy
//  - Cổng từ vựng (Gate) di chuyển dọc theo trục đường băng
//  - Hiệu ứng phát sáng neon khi phát âm đúng (Success Glow) hoặc rung lắc khi sai
//  - Cổng tiếp theo hiển thị trước ở phía xa (Next Gate Preview)
//

import SwiftUI

public struct IsometricFilterCanvas: View {
    public let currentWord: WordItem?
    public let nextWord: WordItem?
    public let gateProgress: Float // 0.0 (xa) -> 1.0 (tại linh vật) -> 1.5 (sau lưng)
    public let isRunning: Bool
    public let isGateSuccess: Bool?

    @State private var roadOffset: CGFloat = 0
    @State private var bobbingOffset: CGFloat = 0

    // Bảng màu chuẩn theo bản Android
    private let runwayLime = Color(red: 0.65, green: 0.93, blue: 0.15)
    private let runwayLimeLight = Color(red: 0.78, green: 0.98, blue: 0.35)
    private let runwayBevel1 = Color(red: 0.33, green: 0.50, blue: 0.18)
    private let runwayBevel2 = Color(red: 0.18, green: 0.28, blue: 0.12)
    private let foxOrange = Color(red: 1.0, green: 0.52, blue: 0.10)
    private let foxLightOrange = Color(red: 1.0, green: 0.68, blue: 0.30)
    private let foxDarkOrange = Color(red: 0.85, green: 0.38, blue: 0.05)
    private let gateWood = Color(red: 0.40, green: 0.25, blue: 0.15)

    public init(
        currentWord: WordItem?,
        nextWord: WordItem? = nil,
        gateProgress: Float = 0.0,
        isRunning: Bool = true,
        isGateSuccess: Bool? = nil
    ) {
        self.currentWord = currentWord
        self.nextWord = nextWord
        self.gateProgress = gateProgress
        self.isRunning = isRunning
        self.isGateSuccess = isGateSuccess
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let width = size.width
                let height = size.height

                let time = timeline.date.timeIntervalSinceReferenceDate
                let dynamicRoadOffset = CGFloat(fmod(time * (isRunning ? 180 : 80), 1000))
                let dynamicBobbing = isRunning ? CGFloat(sin(time * 12.0) * 4.0) : 0.0

                // 1. Vẽ dải đường chạy Isometric 3D
                drawRunway(context: &context, width: width, height: height, roadOffset: dynamicRoadOffset)

                // 2. Tọa độ của chú linh vật cố định trên đường băng
                let charBaseX = width * 0.35
                let charBaseY = height * 0.76 + dynamicBobbing

                // 3. Tính toán vị trí cổng từ vựng dọc theo trục chéo đường băng
                let startGateX = width * 0.90
                let startGateY = height * 0.36
                let targetGateX = width * 0.38
                let targetGateY = height * 0.74

                let clampedProgress = CGFloat(min(gateProgress, 1.0))
                var currentGateX = startGateX + (targetGateX - startGateX) * clampedProgress
                var currentGateY = startGateY + (targetGateY - startGateY) * clampedProgress

                if gateProgress > 1.0 {
                    let overProgress = CGFloat(gateProgress - 1.0)
                    currentGateX -= width * 0.4 * overProgress
                    currentGateY += height * 0.3 * overProgress
                }

                let gateScale = 0.55 + 0.45 * clampedProgress

                // Nếu cổng chưa vượt qua linh vật, vẽ cổng phía sau
                if gateProgress <= 1.0 {
                    drawGate(
                        context: &context,
                        x: currentGateX,
                        y: currentGateY,
                        scale: gateScale,
                        word: currentWord?.word ?? "",
                        isSuccess: isGateSuccess
                    )
                }

                // 4. Vẽ Chú Linh Vật Hoạt Hình Khối Hộp Cam (Low-poly Fox)
                drawCubeFox(
                    context: &context,
                    charX: charBaseX,
                    charY: charBaseY,
                    scale: 1.0,
                    isHappy: isGateSuccess == true
                )

                // Nếu cổng vừa vượt qua con vật (gateProgress > 1.0), vẽ cổng phía trước
                if gateProgress > 1.0 {
                    drawGate(
                        context: &context,
                        x: currentGateX,
                        y: currentGateY,
                        scale: gateScale,
                        word: currentWord?.word ?? "",
                        isSuccess: isGateSuccess
                    )
                }

                // 5. Cổng tiếp theo đang ở phía xa (Next Gate Preview)
                if gateProgress >= 0.7 && nextWord != nil {
                    let nextGateProgress = CGFloat((gateProgress - 0.7) / 0.3 * 0.35)
                    let nextX = startGateX + (targetGateX - startGateX) * nextGateProgress
                    let nextY = startGateY + (targetGateY - startGateY) * nextGateProgress
                    drawGate(
                        context: &context,
                        x: nextX,
                        y: nextY,
                        scale: 0.55 + 0.45 * nextGateProgress,
                        word: nextWord?.word ?? "",
                        isSuccess: nil
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 1. Đường chạy Isometric 3D
    private func drawRunway(context: inout GraphicsContext, width: CGFloat, height: CGFloat, roadOffset: CGFloat) {
        let p1 = CGPoint(x: width * -0.20, y: height * 0.98)
        let p2 = CGPoint(x: width * 0.58, y: height * 0.42)
        let p3 = CGPoint(x: width * 1.25, y: height * 0.42)
        let p4 = CGPoint(x: width * 0.45, y: height * 0.98)

        // Tầng đáy sâu nhất (bevel 2): Màu xám xanh rêu đậm
        var bottomBevel = Path()
        bottomBevel.move(to: CGPoint(x: p1.x, y: p1.y + 35))
        bottomBevel.addLine(to: CGPoint(x: p4.x, y: p4.y + 35))
        bottomBevel.addLine(to: CGPoint(x: p3.x, y: p3.y + 35))
        bottomBevel.addLine(to: p3)
        bottomBevel.addLine(to: p4)
        bottomBevel.addLine(to: p1)
        bottomBevel.closeSubpath()
        context.fill(bottomBevel, with: .color(runwayBevel2))

        // Tầng cạnh dày trên (bevel 1): Màu xám rêu
        var topBevel = Path()
        topBevel.move(to: CGPoint(x: p1.x, y: p1.y + 18))
        topBevel.addLine(to: CGPoint(x: p4.x, y: p4.y + 18))
        topBevel.addLine(to: CGPoint(x: p3.x, y: p3.y + 18))
        topBevel.addLine(to: p3)
        topBevel.addLine(to: p4)
        topBevel.addLine(to: p1)
        topBevel.closeSubpath()
        context.fill(topBevel, with: .color(runwayBevel1))

        // Mặt đường chính: Xanh chanh neon (Lime Green)
        var surface = Path()
        surface.move(to: p1)
        surface.addLine(to: p2)
        surface.addLine(to: p3)
        surface.addLine(to: p4)
        surface.closeSubpath()
        context.fill(surface, with: .color(runwayLime))

        // Hoa văn ô vuông chuyển động dọc theo dải chạy
        for i in 0...12 {
            let t = CGFloat(fmod(Double(CGFloat(i) * 80.0 + roadOffset), 1000.0) / 1000.0)
            let xLeft = p1.x + (p2.x - p1.x) * (1.0 - t)
            let yLeft = p1.y + (p2.y - p1.y) * (1.0 - t)
            let xRight = p4.x + (p3.x - p4.x) * (1.0 - t)
            let yRight = p4.y + (p3.y - p4.y) * (1.0 - t)

            let sqWidth = 24.0 + (1.0 - t) * 20.0
            let sqHeight = 14.0 + (1.0 - t) * 10.0
            let centerX = (xLeft + xRight) / 2.0 + CGFloat((i % 3) - 1) * 45.0
            let centerY = (yLeft + yRight) / 2.0

            let rect = CGRect(x: centerX - sqWidth / 2, y: centerY - sqHeight / 2, width: sqWidth, height: sqHeight)
            let color = (i % 2 == 0) ? runwayLimeLight.opacity(0.65) : Color.white.opacity(0.35)
            context.fill(Path(rect), with: .color(color))
        }

        // Viền sọc đỏ - trắng phong cách F1 ở 2 mép đường chạy
        let stripeCount = 18
        for s in 0..<stripeCount {
            let t1 = CGFloat(s) / CGFloat(stripeCount)
            let t2 = CGFloat(s + 1) / CGFloat(stripeCount)
            let sColor: Color = (s % 2 == 0) ? Color(red: 0.85, green: 0.15, blue: 0.15) : Color.white

            var leftStripe = Path()
            leftStripe.move(to: CGPoint(x: p1.x + (p2.x - p1.x) * (1.0 - t1), y: p1.y + (p2.y - p1.y) * (1.0 - t1)))
            leftStripe.addLine(to: CGPoint(x: p1.x + (p2.x - p1.x) * (1.0 - t2), y: p1.y + (p2.y - p1.y) * (1.0 - t2)))
            context.stroke(leftStripe, with: .color(sColor), style: StrokeStyle(lineWidth: 7, lineCap: .butt))

            var rightStripe = Path()
            rightStripe.move(to: CGPoint(x: p4.x + (p3.x - p4.x) * (1.0 - t1), y: p4.y + (p3.y - p4.y) * (1.0 - t1)))
            rightStripe.addLine(to: CGPoint(x: p4.x + (p3.x - p4.x) * (1.0 - t2), y: p4.y + (p3.y - p4.y) * (1.0 - t2)))
            context.stroke(rightStripe, with: .color(sColor), style: StrokeStyle(lineWidth: 7, lineCap: .butt))
        }
    }

    // MARK: - 2. Chú Linh Vật Hoạt Hình Khối Hộp Cam (Low-poly Fox)
    private func drawCubeFox(context: inout GraphicsContext, charX: CGFloat, charY: CGFloat, scale: CGFloat, isHappy: Bool) {
        let bw = 52.0 * scale
        let bh = 44.0 * scale
        let bd = 32.0 * scale

        // Bóng đổ mờ hình oval trên mặt đường
        let shadowRect = CGRect(x: charX - bw * 0.7, y: charY + bh * 0.7, width: bw * 1.5, height: bh * 0.45)
        context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.35)))

        // Thân hộp - Mặt trước
        let bodyFront = CGRect(x: charX - bw / 2, y: charY - bh / 2, width: bw, height: bh)
        context.fill(Path(roundedRect: bodyFront, cornerRadius: 8), with: .color(foxOrange))

        // Thân hộp - Mặt trên (Isometric lighting: sáng hơn)
        var topFace = Path()
        topFace.move(to: CGPoint(x: charX - bw / 2, y: charY - bh / 2))
        topFace.addLine(to: CGPoint(x: charX - bw / 2 + bd * 0.5, y: charY - bh / 2 - bd * 0.4))
        topFace.addLine(to: CGPoint(x: charX + bw / 2 + bd * 0.5, y: charY - bh / 2 - bd * 0.4))
        topFace.addLine(to: CGPoint(x: charX + bw / 2, y: charY - bh / 2))
        topFace.closeSubpath()
        context.fill(topFace, with: .color(foxLightOrange))

        // Thân hộp - Mặt cạnh phải (Isometric lighting: tối hơn)
        var sideFace = Path()
        sideFace.move(to: CGPoint(x: charX + bw / 2, y: charY - bh / 2))
        sideFace.addLine(to: CGPoint(x: charX + bw / 2 + bd * 0.5, y: charY - bh / 2 - bd * 0.4))
        sideFace.addLine(to: CGPoint(x: charX + bw / 2 + bd * 0.5, y: charY + bh / 2 - bd * 0.4))
        sideFace.addLine(to: CGPoint(x: charX + bw / 2, y: charY + bh / 2))
        sideFace.closeSubpath()
        context.fill(sideFace, with: .color(foxDarkOrange))

        // Bụng trắng (White fur chest)
        let chestRect = CGRect(x: charX - bw * 0.28, y: charY - bh * 0.1, width: bw * 0.56, height: bh * 0.5)
        context.fill(Path(roundedRect: chestRect, cornerRadius: 6), with: .color(Color.white.opacity(0.92)))

        // Mõm cáo hộp trắng
        let snoutRect = CGRect(x: charX - bw * 0.22, y: charY - bh * 0.35, width: bw * 0.44, height: bh * 0.28)
        context.fill(Path(roundedRect: snoutRect, cornerRadius: 4), with: .color(Color.white))

        // Mũi đen nhỏ
        let noseRect = CGRect(x: charX - 4.5 * scale, y: charY - bh * 0.33, width: 9 * scale, height: 6 * scale)
        context.fill(Path(ellipseIn: noseRect), with: .color(Color.black))

        // Đôi mắt cáo đen long lanh (hoặc cong vui sướng khi đúng)
        if isHappy {
            // Mắt cong cười vui sướng ^ ^
            var leftEye = Path()
            leftEye.addArc(center: CGPoint(x: charX - 12 * scale, y: charY - bh * 0.42), radius: 5 * scale, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            context.stroke(leftEye, with: .color(Color.black), style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))

            var rightEye = Path()
            rightEye.addArc(center: CGPoint(x: charX + 12 * scale, y: charY - bh * 0.42), radius: 5 * scale, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            context.stroke(rightEye, with: .color(Color.black), style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
        } else {
            let eyeL = CGRect(x: charX - 15 * scale, y: charY - bh * 0.46, width: 7 * scale, height: 9 * scale)
            let eyeR = CGRect(x: charX + 8 * scale, y: charY - bh * 0.46, width: 7 * scale, height: 9 * scale)
            context.fill(Path(ellipseIn: eyeL), with: .color(Color.black))
            context.fill(Path(ellipseIn: eyeR), with: .color(Color.black))
            // Điểm sáng mắt
            context.fill(Path(ellipseIn: CGRect(x: charX - 14 * scale, y: charY - bh * 0.48, width: 3 * scale, height: 3 * scale)), with: .color(Color.white))
            context.fill(Path(ellipseIn: CGRect(x: charX + 9 * scale, y: charY - bh * 0.48, width: 3 * scale, height: 3 * scale)), with: .color(Color.white))
        }

        // Tai trái
        var earL = Path()
        earL.move(to: CGPoint(x: charX - bw * 0.45, y: charY - bh * 0.45))
        earL.addLine(to: CGPoint(x: charX - bw * 0.32, y: charY - bh * 0.85))
        earL.addLine(to: CGPoint(x: charX - bw * 0.12, y: charY - bh * 0.48))
        earL.closeSubpath()
        context.fill(earL, with: .color(foxOrange))
        // Vành tai trong màu trắng/hồng
        var innerEarL = Path()
        innerEarL.move(to: CGPoint(x: charX - bw * 0.40, y: charY - bh * 0.48))
        innerEarL.addLine(to: CGPoint(x: charX - bw * 0.32, y: charY - bh * 0.78))
        innerEarL.addLine(to: CGPoint(x: charX - bw * 0.18, y: charY - bh * 0.50))
        innerEarL.closeSubpath()
        context.fill(innerEarL, with: .color(Color.white))

        // Tai phải
        var earR = Path()
        earR.move(to: CGPoint(x: charX + bw * 0.12, y: charY - bh * 0.48))
        earR.addLine(to: CGPoint(x: charX + bw * 0.32, y: charY - bh * 0.85))
        earR.addLine(to: CGPoint(x: charX + bw * 0.45, y: charY - bh * 0.45))
        earR.closeSubpath()
        context.fill(earR, with: .color(foxOrange))
        var innerEarR = Path()
        innerEarR.move(to: CGPoint(x: charX + bw * 0.18, y: charY - bh * 0.50))
        innerEarR.addLine(to: CGPoint(x: charX + bw * 0.32, y: charY - bh * 0.78))
        innerEarR.addLine(to: CGPoint(x: charX + bw * 0.40, y: charY - bh * 0.48))
        innerEarR.closeSubpath()
        context.fill(innerEarR, with: .color(Color.white))
    }

    // MARK: - 3. Cổng từ vựng (Word Gate)
    private func drawGate(
        context: inout GraphicsContext,
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat,
        word: String,
        isSuccess: Bool?
    ) {
        guard !word.isEmpty else { return }

        let gateWidth = 135.0 * scale
        let gateHeight = 160.0 * scale
        let colWidth = 18.0 * scale
        let barHeight = 44.0 * scale

        // Màu viền và phát sáng dựa trên trạng thái
        let glowColor: Color
        let borderColor: Color
        if isSuccess == true {
            glowColor = Color.green.opacity(0.85)
            borderColor = Color.green
        } else if isSuccess == false {
            glowColor = Color.red.opacity(0.85)
            borderColor = Color.red
        } else {
            glowColor = runwayLime.opacity(0.6)
            borderColor = runwayLime
        }

        // Cột trái
        let colLeft = CGRect(x: x - gateWidth / 2, y: y - gateHeight, width: colWidth, height: gateHeight)
        context.fill(Path(roundedRect: colLeft, cornerRadius: 4), with: .color(gateWood))
        context.stroke(Path(roundedRect: colLeft, cornerRadius: 4), with: .color(borderColor), style: StrokeStyle(lineWidth: 3 * scale))

        // Cột phải
        let colRight = CGRect(x: x + gateWidth / 2 - colWidth, y: y - gateHeight, width: colWidth, height: gateHeight)
        context.fill(Path(roundedRect: colRight, cornerRadius: 4), with: .color(gateWood))
        context.stroke(Path(roundedRect: colRight, cornerRadius: 4), with: .color(borderColor), style: StrokeStyle(lineWidth: 3 * scale))

        // Thanh ngang đỉnh cổng (Arch header)
        let headerRect = CGRect(x: x - gateWidth / 2 - 8 * scale, y: y - gateHeight - 12 * scale, width: gateWidth + 16 * scale, height: barHeight)
        context.fill(Path(roundedRect: headerRect, cornerRadius: 8 * scale), with: .color(Color.black.opacity(0.85)))
        context.stroke(Path(roundedRect: headerRect, cornerRadius: 8 * scale), with: .color(borderColor), style: StrokeStyle(lineWidth: 4 * scale))

        // Vòng neon phát sáng (Aura) khi đúng
        if isSuccess == true {
            let auraRect = headerRect.insetBy(dx: -8 * scale, dy: -8 * scale)
            context.stroke(Path(roundedRect: auraRect, cornerRadius: 14 * scale), with: .color(glowColor), style: StrokeStyle(lineWidth: 3 * scale))
        }

        // Chữ từ vựng nằm trên biển cổng
        let text = Text(word.uppercased())
            .font(.system(size: max(16 * scale, 12), weight: .heavy, design: .rounded))
            .foregroundColor(.white)

        context.draw(text, at: CGPoint(x: x, y: y - gateHeight + barHeight / 2 - 12 * scale), anchor: .center)
    }
}
