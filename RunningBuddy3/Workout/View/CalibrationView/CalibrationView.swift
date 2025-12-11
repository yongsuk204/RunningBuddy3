import SwiftUI
import CoreLocation

// Purpose: 100m 캘리브레이션 측정 화면
struct CalibrationView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @StateObject private var calibrator = CalibrationSession.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var connectivityManager = PhoneConnectivityManager.shared

    @Binding var calibrationData: CalibrationData?
    let onSaveComplete: () -> Void

    @State private var showingCompletionAlert = false
    @State private var showingCancelAlert = false
    @State private var autoCompleteObserver: NSObjectProtocol?  // 100m 자동완료 알림 구독

    @State private var isGPSReady = false  // GPS 워밍업 완료 여부
    @State private var gpsAccuracyCount = 0  // 5회 연속 좋은 신호 체크
    @State private var countdownSeconds: Int? = nil  // 3-2-1 카운트다운

    // MARK: - Body

    var body: some View {
        ZStack {
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
                headerSection

                if calibrator.isCalibrating {
                    runningSection
                } else {
                    instructionSection
                }

                Spacer()
                buttonSection
            }
            .padding()

            if let seconds = countdownSeconds {
                countdownOverlay(seconds: seconds)
            }
        }
        .alert("측정 완료", isPresented: $showingCompletionAlert) {
            Button("저장") { saveCalibrationData() }
            Button("재측정", role: .cancel) { calibrator.resetCalibration() }
        } message: {
            if let data = calibrationData {
                Text("""
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
            // Watch가 이미 연결되어 있으면 즉시 GPS/센서 활성화
            if connectivityManager.isWatchReachable {
                connectivityManager.sendCommand(.start)
            }

            // 100m 자동완료 알림 구독
            autoCompleteObserver = NotificationCenter.default.addObserver(
                forName: .calibrationAutoComplete,
                object: nil,
                queue: .main
            ) { [self] _ in
                handleStop()
            }
        }
        .onChange(of: connectivityManager.receivedLocation) { _, newValue in
            checkGPSReady(newValue)  // GPS 워밍업 체크 👈 워밍업을 계속 감지하지만 함수내에서 가드문으로 차단함
        }
        .onChange(of: connectivityManager.isWatchReachable) { _, isReachable in
            // Watch가 포그라운드로 전환되면 GPS/센서 활성화
            if isReachable {
                connectivityManager.sendCommand(.start)
            }
        }
        .onDisappear {
            if connectivityManager.isWatchReachable {
                connectivityManager.sendCommand(.stop)  // Watch 센서 중지
            }
            if let observer = autoCompleteObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "ruler")
                .font(.system(size: 60))
                .foregroundColor(.white)

            Text("보폭 캘리브레이션")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.top, 40)
    }

    private var instructionSection: some View {
        VStack(spacing: 24) {
            connectionStatusCard

            VStack(alignment: .leading, spacing: 16) {
                instructionRow(number: "1", text: "워치에서 아이폰연결상태를 확인하세요")
                instructionRow(number: "2", text: "GPS 신호가 안정되면 시작 버튼이 활성화됩니다")
                instructionRow(number: "3", text: "시작 버튼을 누르고 달리기를 시작하세요")
                instructionRow(number: "4", text: "동일한 리듬으로 100m를 달리세요")
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.3)))

            Text(text)
                .font(.body)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var runningSection: some View {
        VStack(spacing: 32) {
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
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        }
    }

    private var buttonSection: some View {
        VStack(spacing: 16) {
            if calibrator.isCalibrating {
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
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.2)))
                } else {
                    VStack(spacing: 12) {
                        Text("100m까지 균일한 리듬으로 달려주세요")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.2)))

                    Button("취소") {
                        showingCancelAlert = true
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            } else {
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

                Button("닫기") {
                    dismiss()
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.bottom, 20)
    }

    private var connectionStatusCard: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // 아이콘: Watch 연결 상태 우선 표시
            Image(systemName: statusIcon)
                .font(DesignSystem.Typography.body)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if let subtitle = statusSubtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(statusColor)
                }
            }

            Spacer()

            // 상태 인디케이터
            if isGPSReady {
                Circle()
                    .fill(DesignSystem.Colors.success)
                    .frame(
                        width: DesignSystem.Layout.statusIndicatorSize * 1.5,
                        height: DesignSystem.Layout.statusIndicatorSize * 1.5
                    )
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: statusColor))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .overlayCardStyle(
            cornerRadius: DesignSystem.CornerRadius.medium,
            shadow: DesignSystem.Shadow.card
        )
    }

    // 연결 상태에 따른 아이콘
    private var statusIcon: String {
        if !connectivityManager.isWatchReachable {
            return "applewatch.slash"
        } else if isGPSReady {
            return "location.fill"
        } else {
            return "location.fill"
        }
    }

    // 연결 상태에 따른 색상
    private var statusColor: Color {
        if !connectivityManager.isWatchReachable {
            return DesignSystem.Colors.error
        } else if isGPSReady {
            return DesignSystem.Colors.success
        } else {
            return DesignSystem.Colors.warning
        }
    }

    // 연결 상태에 따른 메인 타이틀
    private var statusTitle: String {
        if !connectivityManager.isWatchReachable {
            return "Watch 연결 대기 중"
        } else if isGPSReady {
            return "GPS 준비 완료"
        } else {
            return "GPS 신호 수신 중..."
        }
    }

    // 연결 상태에 따른 서브타이틀
    private var statusSubtitle: String? {
        if !connectivityManager.isWatchReachable {
            return "Watch에서 앱을 실행하세요"
        } else if isGPSReady {
            return "측정 시작 가능"
        } else {
            return nil
        }
    }

    private func countdownOverlay(seconds: Int) -> some View {
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

    // MARK: - Helper Methods

    // GPS 워밍업 체크: 5회 연속 정확도 < 20m 확인
    private func checkGPSReady(_ location: CLLocation?) {
        guard !isGPSReady else { return }

        guard let location = location,
              location.horizontalAccuracy > 0,
              location.horizontalAccuracy < 20.0 else {
            gpsAccuracyCount = 0
            return
        }

        gpsAccuracyCount += 1
        if gpsAccuracyCount >= 5 {
            isGPSReady = true
        }
    }

    // 3초 카운트다운 후 측정 시작
    private func startCountdown() {
        guard isGPSReady else { return }

        countdownSeconds = 3
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if let seconds = countdownSeconds {
                if seconds > 1 {
                    countdownSeconds = seconds - 1
                } else {
                    timer.invalidate()
                    countdownSeconds = nil
                    calibrator.startCalibration()
                }
            }
        }
    }

    // 100m 도달 시 자동 호출 (Notification)
    private func handleStop() {
        connectivityManager.sendCommand(.stop)
        if let result = calibrator.stopCalibration() {
            calibrationData = result // 👈 캘리브레이션값 해당변수에 담김
            showingCompletionAlert = true
        }
    }

    // Firestore 저장 후 화면 닫기
    private func saveCalibrationData() {
        guard let data = calibrationData else { return }

        Task {
            // 1. Firestore 저장
            try? await UserService.shared.saveCalibrationRecord(data)

            // 2. 로컬 배열 업데이트 (최신순 정렬)
            await MainActor.run {
                CalibrationSession.shared.calibrationRecords.insert(data, at: 0)
            }

            // 3. 선형 모델 재계산
            await StrideModelCalculator.shared.updateStrideModel(
                from: CalibrationSession.shared.calibrationRecords
            )

            await MainActor.run {
                onSaveComplete()
                dismiss()
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, secs, millis)
    }
}
