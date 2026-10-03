//
//  CameraPreviewView.swift
//  VoiceFilter_iOS
//
//  SwiftUI wrapper cho AVCaptureVideoPreviewLayer:
//  - Đảm bảo tỷ lệ khung dọc 9:16.
//  - Tự động resize frame khi layout thay đổi.
//

import SwiftUI
import AVFoundation

public struct CameraPreviewView: UIViewRepresentable {
    public let previewLayer: AVCaptureVideoPreviewLayer?

    public init(previewLayer: AVCaptureVideoPreviewLayer?) {
        self.previewLayer = previewLayer
    }

    public func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.backgroundColor = .black
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        return view
    }

    public func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        if let previewLayer = previewLayer, previewLayer.superlayer == nil {
            uiView.layer.addSublayer(previewLayer)
        }
    }

    public class PreviewContainerView: UIView {
        public override func layoutSubviews() {
            super.layoutSubviews()
            if let sublayers = layer.sublayers {
                for sublayer in sublayers where sublayer is AVCaptureVideoPreviewLayer {
                    sublayer.frame = bounds
                }
            }
        }
    }
}
