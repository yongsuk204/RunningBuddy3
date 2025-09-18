import SwiftUI
import FirebaseAuth

// 인증된 사용자의 메인 화면 - 간단한 환영 화면
struct MainAppView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 배경 그라데이션
                LinearGradient(
                    colors: [Color.green.opacity(0.3), Color.blue.opacity(0.3), Color.teal.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // 메인 환영 메시지
                    VStack(spacing: 20) {
                        // 앱 아이콘
                        Image(systemName: "figure.run")
                            .font(.system(size: 80))
                            .foregroundColor(.white)

                        Text("환영합니다! 👋")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        if let email = authManager.currentUser?.email {
                            Text(email.components(separatedBy: "@").first ?? "")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Text("Running Buddy에 오신 것을 환영합니다!")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                    )
                    .padding(.horizontal)

                    Spacer()

                    // 로그아웃 버튼
                    Button(action: {
                        authManager.signOut()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title3)

                            Text("로그아웃")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.red.opacity(0.6), lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("Running Buddy")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }
}