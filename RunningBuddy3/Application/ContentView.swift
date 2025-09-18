//
//  ContentView.swift
//  RunningBuddy3
//
//  Created by 배용석 on 9/18/25.
//

import SwiftUI

struct ContentView: View {
    // Purpose: 인증 상태 관리
    @StateObject private var authManager = AuthenticationManager()

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Step 1: 로그인된 사용자는 메인 앱 화면으로
                MainAppView()
                    .environmentObject(authManager)
            } else {
                // Step 2: 로그인 안된 사용자는 로그인 화면으로
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}

#Preview {
    ContentView()
}