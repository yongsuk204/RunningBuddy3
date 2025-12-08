//
//  RunningBuddy3App.swift
//  RunningBuddy3
//
//  Created by 배용석 on 9/18/25.
//

import SwiftUI
import FirebaseCore

// Purpose: SwiftUI 앱 진입점 및 Firebase 초기화 관리
// MARK: - 함수 목록
/*
 * AppDelegate Methods
 * - application(_:didFinishLaunchingWithOptions:): Firebase 초기화
 *
 * App Structure
 * - body: SwiftUI 앱의 UI 계층 구조 정의
 */

// MARK: - AppDelegate

// Purpose: Firebase 초기화를 위한 AppDelegate
// Note: SwiftUI 앱에서 UIApplicationDelegate를 사용하기 위해 NSObject와 UIApplicationDelegate 프로토콜 채택
class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - App Lifecycle

    // Purpose: 앱 시작 시 호출되는 메서드
    // Note: Firebase 초기화를 여기서 처리
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Step 1: Firebase 초기화
        // GoogleService-Info.plist 파일을 읽어 Firebase 서비스를 설정
        FirebaseApp.configure()
        print("Firebase App configured")

        return true
    }
}

// MARK: - SwiftUI App

// Purpose: SwiftUI 앱의 진입점
// Note: @main 어트리뷰트로 앱의 시작점을 표시
@main
struct RunningBuddy3App: App {

    // Purpose: UIKit의 AppDelegate를 SwiftUI 앱에 연결
    // Note: @UIApplicationDelegateAdaptor를 사용하여 Firebase 초기화 및 APNs 설정 처리
    // Why: SwiftUI는 기본적으로 AppDelegate가 없으므로 이 방식으로 연결
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Purpose: 앱의 UI 계층 구조 정의
    var body: some Scene {
        WindowGroup {
            // NavigationView로 감싸서 화면 전환 기능 제공
            NavigationView {
                RootView()
            }
        }
    }
}
