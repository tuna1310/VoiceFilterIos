//
//  SettingsView.swift
//  VoiceFilter_iOS
//
//  Màn hình Cài Đặt (SettingsScreen):
//  - Chuyển đổi ngôn ngữ Tiếng Việt / English
//  - Thanh trượt âm lượng SFX và Nhạc nền (BGM)
//  - Tùy chọn nhận diện giọng nói On-Device hoặc Cloud
//  - Đồng bộ từ vựng từ xa qua Supabase Cloud / Remote Config
//  - Thông tin phiên bản và Bản quyền
//

import SwiftUI

public struct SettingsView: View {
    public let onBack: () -> Void

    @ObservedObject private var settings = SettingsRepository.shared
    @ObservedObject private var soundManager = SoundEffectManager.shared
    @ObservedObject private var vocabRepo = VocabularyRepository.shared

    @State private var syncStatusMessage: String? = nil

    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }

    public var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 20) {
                // Header Bar
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }

                    Text("Settings")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Section 1: Âm Thanh
                        VStack(alignment: .leading, spacing: 14) {
                            Text("SOUND & EFFECTS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            VStack(spacing: 16) {
                                // SFX Volume
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Sound Effects (SFX)")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(settings.sfxVolume * 100))%")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
                                    }
                                    Slider(value: $settings.sfxVolume, in: 0...1, step: 0.05)
                                        .tint(Color(red: 0.65, green: 0.93, blue: 0.15))
                                        .onChange(of: settings.sfxVolume) { _ in
                                            soundManager.updateVolumes()
                                        }
                                }

                                Divider().background(Color.white.opacity(0.1))

                                // BGM Volume
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Background Music (BGM)")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(settings.bgmVolume * 100))%")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
                                    }
                                    Slider(value: $settings.bgmVolume, in: 0...1, step: 0.05)
                                        .tint(Color(red: 0.65, green: 0.93, blue: 0.15))
                                        .onChange(of: settings.bgmVolume) { _ in
                                            soundManager.updateVolumes()
                                        }
                                }
                            }
                            .padding(16)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .cornerRadius(20)
                        }

                        // Section 2: Ngôn Ngữ & Nhận Diện
                        VStack(alignment: .leading, spacing: 14) {
                            Text("LANGUAGE & SPEECH RECOGNITION")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            VStack(spacing: 16) {
                                HStack {
                                    Text("Interface Language")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Picker("Language", selection: $settings.language) {
                                        ForEach(AppLanguage.allCases) { lang in
                                            Text(lang.displayName).tag(lang)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }

                                Divider().background(Color.white.opacity(0.1))

                                Toggle(isOn: $settings.preferOnDeviceSpeech) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Prefer On-Device Recognition")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("No internet needed, faster response")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .tint(Color(red: 0.65, green: 0.93, blue: 0.15))
                            }
                            .padding(16)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .cornerRadius(20)
                        }

                        // Section 3: Đồng Bộ Dữ Liệu Từ Xa (Remote Config / Supabase)
                        VStack(alignment: .leading, spacing: 14) {
                            Text("REMOTE VOCABULARY UPDATE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            VStack(spacing: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Current Word Bank")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(vocabRepo.lastSyncDate != nil ? "Last synced: \(formatSyncDate(vocabRepo.lastSyncDate!))" : "Local offline data")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text("\(vocabRepo.allWords.count) words")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
                                }

                                if let msg = syncStatusMessage {
                                    Text(msg)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.orange)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Divider().background(Color.white.opacity(0.1))

                                Button(action: triggerManualSync) {
                                    HStack(spacing: 8) {
                                        if vocabRepo.isSyncing {
                                            ProgressView().tint(.black).scaleEffect(0.8)
                                            Text("Syncing with Supabase...")
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                            Text("Sync New Vocabulary (Cloud Sync)")
                                        }
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 0.65, green: 0.93, blue: 0.15))
                                    .cornerRadius(14)
                                }
                                .disabled(vocabRepo.isSyncing)
                            }
                            .padding(16)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .cornerRadius(20)
                        }

                        // Section 4: Về Ứng Dụng
                        VStack(alignment: .leading, spacing: 14) {
                            Text("ABOUT")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            VStack(spacing: 12) {
                                HStack {
                                    Text("Version")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("1.0.0 (Native iOS)")
                                        .foregroundColor(.gray)
                                }
                                Divider().background(Color.white.opacity(0.1))
                                HStack {
                                    Text("AR Graphics")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("SwiftUI Canvas 3D")
                                        .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
                                }
                                Divider().background(Color.white.opacity(0.1))
                                HStack {
                                    Text("Video Export")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("MP4 9:16 + Watermark + SFX Mix")
                                        .foregroundColor(Color(red: 0.65, green: 0.93, blue: 0.15))
                                }
                                Divider().background(Color.white.opacity(0.1))
                                HStack {
                                    Text("Word Bank")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(vocabRepo.allWords.count) words & phrases (12 topics)")
                                        .foregroundColor(.gray)
                                }
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(16)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func triggerManualSync() {
        syncStatusMessage = nil
        vocabRepo.syncRemoteVocabulary { success, errMsg in
            DispatchQueue.main.async {
                if success {
                    self.syncStatusMessage = "Latest vocabulary synced successfully!"
                } else {
                    self.syncStatusMessage = errMsg ?? "Sync failed; offline data kept."
                }
            }
        }
    }

    private func formatSyncDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd/MM/yyyy"
        return formatter.string(from: date)
    }
}
