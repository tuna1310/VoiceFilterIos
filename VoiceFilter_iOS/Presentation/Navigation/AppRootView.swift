//
//  AppRootView.swift
//  VoiceFilter_iOS
//
//  Điều phối luồng màn hình chính của ứng dụng:
//  Splash -> Onboarding -> Cấp quyền -> Trang chủ (Home) <-> Chủ đề (Subjects) <-> Thử Thách AR (Challenge) <-> Cài đặt
//

import SwiftUI

public enum AppRoute: Equatable {
    case splash
    case onboarding
    case permissions
    case home
    case subjects
    case subjectDetail(subject: Subject)
    case challenge(subject: Subject, difficulty: DifficultyLevel, gameMode: GameModeType, words: [WordItem])
    case settings
}

public struct AppRootView: View {
    @State private var currentRoute: AppRoute = .splash
    @StateObject private var permissionManager = PermissionManager.shared
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false

    public init() {}

    public var body: some View {
        Group {
            switch currentRoute {
            case .splash:
                SplashView {
                    if !hasCompletedOnboarding {
                        currentRoute = .onboarding
                    } else if !permissionManager.hasCorePermissions {
                        currentRoute = .permissions
                    } else {
                        currentRoute = .home
                    }
                }

            case .onboarding:
                OnboardingView {
                    hasCompletedOnboarding = true
                    if !permissionManager.hasCorePermissions {
                        currentRoute = .permissions
                    } else {
                        currentRoute = .home
                    }
                }

            case .permissions:
                PermissionRequestView {
                    currentRoute = .home
                }

            case .home:
                HomeView(
                    onSelectChallenge: { subject, difficulty, mode in
                        let words = VocabularyRepository.shared.getWords(for: subject, difficulty: difficulty, gameMode: mode)
                        currentRoute = .challenge(subject: subject, difficulty: difficulty, gameMode: mode, words: words)
                    },
                    onSelectSubject: { subj in
                        currentRoute = .subjectDetail(subject: subj)
                    },
                    onOpenSettings: {
                        currentRoute = .settings
                    }
                )

            case .subjects:
                SubjectsView(
                    onSelectSubject: { subj in
                        currentRoute = .subjectDetail(subject: subj)
                    },
                    onBack: {
                        currentRoute = .home
                    }
                )

            case .subjectDetail(let subject):
                SubjectDetailView(
                    subject: subject,
                    onStartChallenge: { subj, diff, mode in
                        let words = VocabularyRepository.shared.getWords(for: subj, difficulty: diff, gameMode: mode)
                        currentRoute = .challenge(subject: subj, difficulty: diff, gameMode: mode, words: words)
                    },
                    onBack: {
                        currentRoute = .home
                    }
                )

            case .challenge(let subject, let difficulty, let gameMode, let words):
                CameraRecordView(
                    subject: subject,
                    difficulty: difficulty,
                    gameMode: gameMode,
                    words: words,
                    onFinish: { _ in
                        currentRoute = .home
                    }
                )

            case .settings:
                SettingsView {
                    currentRoute = .home
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
