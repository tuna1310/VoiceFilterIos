//
//  VoiceFilterApp.swift
//  VoiceFilter_iOS
//
//  Entry point của ứng dụng Voice Filter: Speak Challenge (iOS):
//  - Quản lý toàn bộ vòng đời ứng dụng và điều hướng qua AppRootView
//

import SwiftUI

@main
struct VoiceFilterApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
    }
}
