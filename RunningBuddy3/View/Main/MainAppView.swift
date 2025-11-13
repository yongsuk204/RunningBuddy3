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
                Color.clear
                    .appGradientBackground()

                ScrollView {
                    VStack(spacing: 40) {
                        // 메뉴 그리드 (2x2)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            // 센서 데이터
                            NavigationLink(destination: SensorDataView()) {
                                GridMenuButton(
                                    icon: "sensor.fill",
                                    title: "실시간 센서",
                                    color: .white
                                )
                            }

                            // 프로필
                            NavigationLink(destination: Text("프로필 화면 (준비중)")) {
                                GridMenuButton(
                                    icon: "person.circle.fill",
                                    title: "프로필",
                                    color: .white
                                )
                            }

                            // 설정
                            NavigationLink(destination: SettingsView()) {
                                GridMenuButton(
                                    icon: "gearshape.fill",
                                    title: "설정",
                                    color: .white
                                )
                            }
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
        )
    }
}
