//
//  RunningBuddy3App.swift
//  RunningBuddy3
//
//  Created by 배용석 on 9/18/25.
//

import SwiftUI
import FirebaseCore

// Purpose: Firebase 초기화를 위한 AppDelegate 클래스
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Step 1: Firebase 설정 초기화
        FirebaseApp.configure()
        return true
    }
}

@main
struct RunningBuddy3App: App {
    // Purpose: Firebase setup을 위한 AppDelegate 등록
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }
    }
}
