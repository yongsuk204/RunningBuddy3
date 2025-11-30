import SwiftUI

// Purpose: 100m 캘리브레이션 측정 화면
struct CalibrationView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @StateObject private var calibrator = StrideCalibratorService.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    // 👈 settingview.loadCalibrationData() 함수를 통해서 가져온 calibrationData
    // 👈SettingsView.swift 54번줄에 $calibrationData 통해서 전달함
    @Binding var calibrationData: CalibrationData? 

    // 👈 SettingsView.saveCalibrationData() 실행
    // 👈SettingsView.swift 54번줄에 onsave: 를 통해서 부모뷰의 함수를 사용할 수 있음
    let onSave: () -> Void 

    // State Properties
    @State private var showingCompletionAlert = false
    @State private var showingCancelAlert = false
    @State private var autoCompleteObserver: NSObjectProtocol?

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                colors: [
                    themeManager.gradientStart.opacity(0.6),
                    themeManager.gradientEnd.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // 헤더
                headerSection

                // 측정 상태 표시
                if calibrator.isCalibrating {
                    runningSection
                } else {
                    instructionSection
                }

                Spacer()

                // 버튼 섹션
                buttonSection
            }
            .padding()
        }
        .alert("측정 완료", isPresented: $showingCompletionAlert) {
            Button("저장", role: .none) {
                onSave()
                dismiss()
            }
            Button("재측정", role: .cancel) {
                calibrator.resetCalibration()
            }
        } message: {
            if let data = calibrationData {
                Text("""
                GPS 거리: 100m
                걸음 수: \(data.totalSteps)걸음
                평균 케이던스: \(String(format: "%.0f", data.averageCadence)) SPM
                평균 보폭: \(String(format: "%.2f", data.averageStepLength))m

                이 데이터를 저장하시겠습니까?
                """)
            }
        }
        .alert("측정 취소", isPresented: $showingCancelAlert) {
            Button("계속 측정", role: .cancel) {}
            Button("취소", role: .destructive) {
                calibrator.resetCalibration()
                dismiss()
            }
        } message: {
            Text("진행 중인 측정을 취소하시겠습니까?")
        }
        .onAppear {
            // 자동 완료 알림 구독
            autoCompleteObserver = NotificationCenter.default.addObserver(
                forName: .calibrationAutoComplete,
                object: nil,
                queue: .main
            ) { [self] _ in
                handleStop()
            }
        }
        .onDisappear {
            // 알림 구독 해제
            if let observer = autoCompleteObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    // MARK: - Header Section
    // ═══════════════════════════════════════
    // PURPOSE: 헤더 섹션
    // ═══════════════════════════════════════
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)

            Text("100m 보폭 측정")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.top, 40)
    }

    // MARK: - Instruction Section
    // ═══════════════════════════════════════
    // PURPOSE: 측정 안내 섹션
    // ═══════════════════════════════════════
    private var instructionSection: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                instructionRow(number: "1", text: "야외 GPS 신호가 잘 잡히는 곳으로 이동하세요")
                instructionRow(number: "2", text: "시작 버튼을 누르고 달리기를 시작하세요")
                instructionRow(number: "3", text: "GPS가 100m를 자동으로 측정합니다")
                instructionRow(number: "4", text: "100m 도달 시 자동으로 종료됩니다")
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )

            VStack(spacing: 8) {
                Text("⚠️ Watch를 왼쪽 발목에 착용하세요")
                    .font(.caption)
                    .foregroundColor(.yellow)

                Text("📍 GPS 정확도를 위해 야외에서 측정하세요")
                    .font(.caption)
                    .foregroundColor(.cyan)
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 안내 행
    // ═══════════════════════════════════════
    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.3))
                )

            Text(text)
                .font(.body)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Running Section
    // ═══════════════════════════════════════
    // PURPOSE: 측정 진행 중 섹션
    // ═══════════════════════════════════════
    private var runningSection: some View {
        VStack(spacing: 32) {
            // GPS 거리 (가장 크게 표시)
            VStack(spacing: 8) {
                Text("GPS 거리")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                Text(String(format: "%.1f", calibrator.currentDistance))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(calibrator.hasReached100m ? .green : .white)

                Text("/ 100.0 m")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(calibrator.hasReached100m ? Color.green.opacity(0.2) : Color.clear)
            )

            // 경과 시간
            VStack(spacing: 8) {
                Text("경과 시간")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                Text(formatTime(calibrator.elapsedTime))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // 실시간 데이터
            HStack(spacing: 16) {
                // 걸음 수
                VStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                        .foregroundColor(.white)

                    Text("\(calibrator.currentSteps)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("걸음")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )

                // 케이던스
                VStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.title2)
                        .foregroundColor(.white)

                    Text(String(format: "%.0f", calibrator.currentCadence))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("SPM")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    // MARK: - Button Section
    // ═══════════════════════════════════════
    // PURPOSE: 버튼 섹션
    // ═══════════════════════════════════════
    private var buttonSection: some View {
        VStack(spacing: 16) {
            if calibrator.isCalibrating {
                // 100m 도달 상태 표시
                if calibrator.hasReached100m {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("100m 도달 완료!")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .font(.headline)

                        Text("잠시 후 자동으로 결과가 표시됩니다")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.2))
                    )
                } else {
                    // 100m 미도달 - 측정 중
                    VStack(spacing: 12) {
                        Text("100m까지 달려주세요")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("GPS가 100m를 자동으로 감지합니다")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.2))
                    )

                    // 취소 버튼만 표시
                    Button {
                        showingCancelAlert = true
                    } label: {
                        Text("취소")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else {
                // 시작 버튼
                Button {
                    calibrator.startCalibration()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("측정 시작")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // 닫기 버튼
                Button {
                    dismiss()
                } label: {
                    Text("닫기")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 측정 종료 처리
    // ═══════════════════════════════════════
    private func handleStop() {
        if let result = calibrator.stopCalibration() {
            calibrationData = result
            showingCompletionAlert = true
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 시간 포맷팅
    // ═══════════════════════════════════════
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, secs, millis)
    }
}
