//
//  RootView.swift
//  RunningBuddy3
//
//  Created by 배용석 on 9/18/25.
//

import SwiftUI

// Purpose: 앱의 루트 뷰 - 인증 상태에 따라 LoginView 또는 MainAppView로 라우팅
struct RootView: View {
    // Purpose: 인증 상태 관리
    @StateObject private var authManager = AuthenticationManager()

    // Purpose: 에러 알림 표시 상태
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        Group {
            if authManager.currentUser != nil {
                // Step 1: 로그인된 사용자는 메인 앱 화면으로
                MainAppView()
            } else {
                // Step 2: 로그인 안된 사용자는 로그인 화면으로
                LoginView()
            }
        }
        .environmentObject(authManager)  // ← Group 레벨에서 제공

        // 👈 알람처리를 하는 부분
        .alert("오류", isPresented: $showAlert) {
            Button("확인", role: .cancel) {
                authManager.errorMessage = ""
            }
        } message: {
            Text(alertMessage)
        }
        // 👈 데이터 감지함
        .onChange(of: authManager.errorMessage) { oldValue, newValue in
            if !newValue.isEmpty {
                alertMessage = newValue
                showAlert = true
            }
        }
    }
}
