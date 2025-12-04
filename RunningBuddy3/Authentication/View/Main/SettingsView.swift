import SwiftUI
import FirebaseAuth

// Purpose: 앱 설정 화면 - 캘리브레이션, 로그아웃 기능
struct SettingsView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    // Calibration Properties
    @State private var calibrationData: CalibrationData? = nil
    @State private var showingCalibrationView = false
    @State private var showingCalibrationHistory = false

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
        .sheet(isPresented: $showingCalibrationView) {
            CalibrationView(
                calibrationData: $calibrationData
            ) {
                // 저장 완료 후 콜백 (필요 시 SettingsView 새로고침)
                print("ℹ️ SettingsView: 캘리브레이션 저장 완료 콜백")
            }
        }
        .sheet(isPresented: $showingCalibrationHistory) {
            NavigationStack {
                CalibrationHistoryView()
            }
        }
    }

    // MARK: - Calibration Section
    // ═══════════════════════════════════════
    // PURPOSE: 100m 캘리브레이션 섹션
    // ═══════════════════════════════════════
    private var calibrationSection: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            HStack {
                Image(systemName: "ruler")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("100m 보폭 측정")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            if let calibration = calibrationData {
                // 캘리브레이션 데이터 표시
                VStack(spacing: 12) {
                    // 평균 보폭
                    HStack {
                        Text("평균 보폭")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Text(String(format: "%.2f m", calibration.averageStepLength))
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    Divider()
                        .background(Color.white.opacity(0.3))

                    // 걸음 수
                    HStack {
                        Text("걸음 수")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Text("\(calibration.totalSteps) 걸음")
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    Divider()
                        .background(Color.white.opacity(0.3))

                    // 평균 케이던스
                    HStack {
                        Text("평균 케이던스")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Text(String(format: "%.0f SPM", calibration.averageCadence))
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    // 버튼 그룹
                    HStack(spacing: 12) {
                        // 재측정 버튼
                        Button {
                            showingCalibrationView = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("재측정")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.2))
                            )
                        }

                        // 히스토리 버튼
                        Button {
                            showingCalibrationHistory = true
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("히스토리")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.3))
                            )
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            } else {
                // 캘리브레이션 측정 안내
                VStack(spacing: 12) {
                    Button {
                        showingCalibrationView = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.run")
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("100m 측정하기")
                                    .font(.headline)

                                Text("다양한 속도로 5회 이상 측정 권장")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

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
