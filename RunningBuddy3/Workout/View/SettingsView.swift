import SwiftUI
import FirebaseAuth

// Purpose: 앱 설정 화면 - 캘리브레이션, 로그아웃 기능
struct SettingsView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss


    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션
            Color.clear
                .appGradientBackground()

            VStack(spacing: 24) {
                // 캘리브레이션 섹션
                calibrationSection

                // 계정 섹션
                accountSection

                Spacer()
            }
            .padding()
            .padding(.top, 8)
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Calibration Section
    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 섹션 (간소화 버전)
    // ═══════════════════════════════════════
    private var calibrationSection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Image(systemName: "ruler")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("캘리브레이션")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            // NavigationLink to CalibrationHistoryView
            NavigationLink {
                CalibrationHistoryView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)

                    Text("측정 기록 보기")
                        .font(.headline)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.5))
                }
                .foregroundColor(.white)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("계정")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            // 로그아웃 버튼
            Button {
                handleLogout()
            } label: {
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
                )
            }
        }
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 안전한 로그아웃 처리
    // ═══════════════════════════════════════
    private func handleLogout() {
        // Step 1: 화면 닫기
        dismiss()

        // Step 2: 뷰가 완전히 사라진 후 로그아웃
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            authManager.signOut()
        }
    }
}
