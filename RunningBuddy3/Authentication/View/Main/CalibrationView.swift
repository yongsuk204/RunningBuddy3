import SwiftUI
import CoreLocation

// Purpose: 100m 캘리브레이션 측정 화면
struct CalibrationView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @StateObject private var calibrator = StrideCalibratorService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var connectivityManager = PhoneConnectivityManager.shared

    // 👈 측정 완료된 calibrationData
    @Binding var calibrationData: CalibrationData?

    // 👈 저장 완료 후 콜백 (부모 뷰 새로고침용)
    let onSaveComplete: () -> Void 

    // State Properties
    @State private var showingCompletionAlert = false
    @State private var showingCancelAlert = false
    @State private var autoCompleteObserver: NSObjectProtocol?
    @State private var isSaving = false

    // GPS Warmup State
    @State private var isGPSWarming = false
    @State private var isGPSReady = false
    @State private var gpsAccuracyHistory: [Double] = []  // 3회 연속 정확도 체크
    @State private var countdownSeconds: Int? = nil
    @State private var countdownTimer: Timer? = nil

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

            // 카운트다운 오버레이 (전체 화면)
            if let seconds = countdownSeconds {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        Text("\(seconds)")
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("준비...")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .transition(.opacity)
            }
        }
        .alert("측정 완료", isPresented: $showingCompletionAlert) {
            Button("저장", role: .none) {
                saveCalibrationData()
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
            // Step 1: Watch 연결 확인
            guard connectivityManager.isWatchReachable else {
                // GPS 워밍업 불가 상태로 설정
                isGPSWarming = false
                isGPSReady = false
                print("⚠️ Apple Watch가 연결되지 않았습니다")
                return
            }

            // Step 2: Watch GPS 및 센서 활성화 (워밍업용)
            connectivityManager.sendCommand(.start)
            print("📡 GPS 워밍업을 위해 Watch 센서 활성화")

            // Step 3: GPS 워밍업 시작
            startGPSWarmup()

            // Step 4: 자동 완료 알림 구독
            autoCompleteObserver = NotificationCenter.default.addObserver(
                forName: .calibrationAutoComplete,
                object: nil,
                queue: .main
            ) { [self] _ in
                handleStop()
            }
        }
        .onChange(of: connectivityManager.receivedLocation) { oldValue, newValue in
            handleGPSAccuracyChange(newValue)
        }
        .onChange(of: connectivityManager.isWatchReachable) { oldValue, newValue in
            // Watch 연결 끊김 감지 (워밍업 중일 때만)
            if isGPSWarming && !newValue {
                isGPSWarming = false
                isGPSReady = false
                gpsAccuracyHistory.removeAll()
                print("⚠️ Apple Watch 연결이 끊어졌습니다")
            }
        }
        .onDisappear {
            // Watch 센서 중지 (배터리 절약)
            if connectivityManager.isWatchReachable {
                connectivityManager.sendCommand(.stop)
                print("⏹️ CalibrationView 종료 - Watch 센서 중지")
            }

            // 카운트다운 타이머 정리
            countdownTimer?.invalidate()
            countdownTimer = nil
            countdownSeconds = nil

            // GPS 워밍업 상태 정리
            isGPSWarming = false
            isGPSReady = false
            gpsAccuracyHistory.removeAll()

            // 알림 구독 해제
            if let observer = autoCompleteObserver {
                NotificationCenter.default.removeObserver(observer)
            }

            print("🔄 CalibrationView 종료 - GPS 워밍업 정리")
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
            // GPS 상태 카드
            gpsStatusCard

            VStack(alignment: .leading, spacing: 16) {
                instructionRow(number: "1", text: "야외 GPS 신호가 잘 잡히는 곳으로 이동하세요")
                instructionRow(number: "2", text: "GPS 신호가 안정되면 시작 버튼이 활성화됩니다")
                instructionRow(number: "3", text: "시작 버튼을 누르고 달리기를 시작하세요")
                instructionRow(number: "4", text: "GPS가 100m를 자동으로 측정합니다")
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
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
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
                    startCountdown()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("측정 시작")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isGPSReady ? Color.green : Color.gray.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isGPSReady)

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

    // MARK: - GPS Status Card
    // ═══════════════════════════════════════
    // PURPOSE: GPS 워밍업 상태 카드
    // ═══════════════════════════════════════
    private var gpsStatusCard: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // 아이콘
            Image(systemName: isGPSReady ? "location.fill" : (isGPSWarming ? "location.fill" : "location.slash"))
                .font(DesignSystem.Typography.body)
                .foregroundColor(isGPSReady ? DesignSystem.Colors.success : (isGPSWarming ? DesignSystem.Colors.warning : DesignSystem.Colors.neutral))

            VStack(alignment: .leading, spacing: 4) {
                // 상태 텍스트
                Text(isGPSReady ? "GPS 준비 완료" : (isGPSWarming ? "GPS 신호 수신 중..." : "GPS 대기 중"))
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                // 상세 정보
                if isGPSWarming {
                    Text("\(gpsAccuracyHistory.count)/3 회 신호 수신")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                } else if isGPSReady {
                    Text("측정 시작 가능")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.success)
                }
            }

            Spacer()

            // 상태 인디케이터
            if isGPSWarming {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.warning))
            } else {
                Circle()
                    .fill(isGPSReady ? DesignSystem.Colors.success : DesignSystem.Colors.neutral)
                    .frame(
                        width: DesignSystem.Layout.statusIndicatorSize * 1.5,
                        height: DesignSystem.Layout.statusIndicatorSize * 1.5
                    )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .overlayCardStyle(
            cornerRadius: DesignSystem.CornerRadius.medium,
            shadow: DesignSystem.Shadow.card
        )
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: GPS 워밍업 시작
    // FUNCTIONALITY:
    //   - GPS 워밍업 상태 활성화
    //   - 정확도 히스토리 초기화
    // ═══════════════════════════════════════
    private func startGPSWarmup() {
        isGPSWarming = true
        isGPSReady = false
        gpsAccuracyHistory.removeAll()
        print("🔄 GPS 워밍업 시작...")
    }

    // ═══════════════════════════════════════
    // PURPOSE: GPS 정확도 변화 감지 및 준비 상태 업데이트
    // FUNCTIONALITY:
    //   - 3회 연속 horizontalAccuracy < 20m 확인
    //   - GPS 준비 완료 시 버튼 활성화
    // ═══════════════════════════════════════
    private func handleGPSAccuracyChange(_ location: CLLocation?) {
        guard isGPSWarming, !isGPSReady else { return }

        guard let location = location,
              location.horizontalAccuracy > 0,
              location.horizontalAccuracy < 20.0 else {
            // 정확도 불충분 - 히스토리 초기화
            gpsAccuracyHistory.removeAll()
            return
        }

        // 정확도 히스토리에 추가
        gpsAccuracyHistory.append(location.horizontalAccuracy)

        // 3회 연속 좋은 신호 확인
        if gpsAccuracyHistory.count >= 3 {
            isGPSReady = true
            isGPSWarming = false
            print("✅ GPS 준비 완료! (연속 3회 정확도: \(gpsAccuracyHistory.map { String(format: "%.1fm", $0) }.joined(separator: ", ")))")
        } else {
            print("📡 GPS 워밍업 중... (\(gpsAccuracyHistory.count)/3)")
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 3초 카운트다운 시작
    // FUNCTIONALITY:
    //   - 1초마다 카운트 감소
    //   - 0에 도달하면 측정 시작
    // ═══════════════════════════════════════
    private func startCountdown() {
        guard isGPSReady else {
            print("⚠️ GPS가 준비되지 않았습니다")
            return
        }

        countdownSeconds = 3

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let seconds = countdownSeconds {
                if seconds > 1 {
                    // 카운트다운 계속
                    countdownSeconds = seconds - 1
                } else {
                    // 카운트다운 완료 - 측정 시작
                    countdownTimer?.invalidate()
                    countdownTimer = nil
                    countdownSeconds = nil
                    startCalibrationMeasurement()
                }
            }
        }

        print("⏱️ 3초 카운트다운 시작")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 측정 실제 시작
    // FUNCTIONALITY:
    //   - StrideCalibratorService 측정 시작 (Watch는 이미 .onAppear에서 활성화됨)
    // NOTE: Watch GPS/sensors already activated in .onAppear for warmup
    // ═══════════════════════════════════════
    private func startCalibrationMeasurement() {
        // Step 1: StrideCalibratorService 측정 시작 (tempDistanceCalculator 사용)
        calibrator.startCalibration()

        print("▶️ 캘리브레이션 측정 시작 (Watch 이미 활성화됨, tempDistanceCalculator 사용)")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 측정 종료 처리
    // FUNCTIONALITY:
    //   - Watch에 측정 중지 명령 전송
    //   - 캘리브레이션 결과 저장
    // ═══════════════════════════════════════
    private func handleStop() {
        // Step 1: Watch에 측정 중지 명령 전송
        connectivityManager.sendCommand(.stop)

        // Step 2: 캘리브레이션 결과 처리
        if let result = calibrator.stopCalibration() {
            calibrationData = result
            showingCompletionAlert = true
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 데이터 저장 (Firestore)
    // FUNCTIONALITY:
    //   - StrideCalibratorService를 통해 Firestore 저장
    //   - 저장 완료 후 부모 뷰 콜백 실행
    //   - 저장 완료 후 dismiss
    // ═══════════════════════════════════════
    private func saveCalibrationData() {
        guard let data = calibrationData else {
            print("⚠️ CalibrationView: calibrationData가 nil입니다")
            return
        }

        isSaving = true

        Task {
            // StrideCalibratorService를 통해 Firestore 저장 (중복 저장 방지)
            await calibrator.addCalibrationRecord(data)

            print("✅ CalibrationView: 캘리브레이션 데이터 저장 완료")

            await MainActor.run {
                isSaving = false
                onSaveComplete()  // 부모 뷰 콜백 (히스토리 새로고침 등)
                dismiss()
            }
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
