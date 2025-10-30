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

                ScrollView {
                    VStack(spacing: 40) {
                        // 메뉴 그리드 (2x2)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            // 센서 데이터
                            NavigationLink(destination: SensorDataView()) {
                                GridMenuButton(
                                    icon: "sensor.fill",
                                    title: "실시간 센서",
                                    color: .green
                                )
                            }

                            // 프로필
                            NavigationLink(destination: Text("프로필 화면 (준비중)")) {
                                GridMenuButton(
                                    icon: "person.circle.fill",
                                    title: "프로필",
                                    color: .blue
                                )
                            }

                            // 설정
                            NavigationLink(destination: Text("설정 화면 (준비중)")) {
                                GridMenuButton(
                                    icon: "gearshape.fill",
                                    title: "설정",
                                    color: .purple
                                )
                            }
                        }
                        .padding(.horizontal)

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
            }
        }
    }
}

// MARK: - Grid Menu Button

struct GridMenuButton: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(color)

            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
}
