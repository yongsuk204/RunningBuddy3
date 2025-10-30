import SwiftUI
import CoreLocation

// Purpose: iPhone에서 Apple Watch 센서 데이터 실시간 표시 및 CSV 저장 화면
struct SensorDataView: View {

    // MARK: - Properties
    /*
     작동 원리:
       - 각 매니저의 @Published 프로퍼티 값이 변경되면
       - SwiftUI가 자동으로 감지
       - 해당 View를 자동으로 다시 렌더링
     */
    @StateObject private var connectivityManager = PhoneConnectivityManager.shared
    @StateObject private var exporter = SensorDataExporter()
    @StateObject private var cadenceCalculator = CadenceCalculator.shared
    @StateObject private var distanceCalculator = DistanceCalculator.shared

    // Purpose: 파일 공유 시트 표시 여부
    @State private var showingShareSheet = false

    // Purpose: 공유할 CSV 파일 URL
    @State private var csvFileURL: URL?

    // Purpose: 알림 표시 여부
    @State private var showingAlert = false

    // Purpose: 알림 메시지
    @State private var alertMessage = ""

    // Purpose: 워치 운동 측정 상태
    @State private var isWatchMonitoring = false

    // Purpose: 측정 시작 시간
    @State private var monitoringStartTime: Date?

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3), Color.teal.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 상태 헤더
                    statusHeader

                    // 센서 데이터 카드들
                    // 이동 거리 카드 (항상 표시)
                    DistanceCard(distance: distanceCalculator.totalDistance)

                    // 러닝 경로 지도 카드 (항상 표시)
                    MapCard(locations: distanceCalculator.locations)

                    // 심박수 카드 (항상 표시)
                    HeartRateCard(heartRate: connectivityManager.receivedSensorData?.heartRate ?? 0)

                    // 케이던스 카드 (항상 표시)
                    CadenceCard(cadence: cadenceCalculator.currentCadence)

                    // 타임스탬프 (데이터가 있을 때만 표시)
                    if let timestamp = connectivityManager.receivedSensorData?.timestamp {
                        Text("측정 시간: \(timestamp, style: .time)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("실시간 센서")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                workoutControlButton
            }

            ToolbarItem(placement: .topBarTrailing) {
                recordButton
            }
        }
        .onChange(of: connectivityManager.receivedSensorData) { oldValue, newValue in
            if let data = newValue {
                // Step 1: CSV 저장용 데이터 추가
                exporter.addSensorData(data)

                // Step 2: 실시간 케이던스 계산용 버퍼에 추가 (슬라이딩 윈도우 자동 관리)
                cadenceCalculator.addSensorData(data)
            }
        }
        .onChange(of: connectivityManager.receivedLocation) { oldValue, newValue in
            // GPS 위치가 수신되면 DistanceCalculator로 전달
            if let location = newValue {
                distanceCalculator.addLocation(location)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = csvFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert("알림", isPresented: $showingAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // 화면 진입 시 연결 상태 로그 출력
            print("📱 SensorDataView 진입 - Watch 연결 상태: \(connectivityManager.isWatchReachable)")
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 12) {
            // Apple Watch 연결 상태
            watchConnectionStatus

            // GPS 수신 상태
            gpsSignalStatus

            // 가속도계 상태
            sensorStatus(
                icon: "move.3d",
                name: "가속도계",
                isActive: connectivityManager.receivedSensorData != nil,
                color: .blue
            )

            // 자이로스코프 상태
            sensorStatus(
                icon: "gyroscope",
                name: "자이로스코프",
                isActive: connectivityManager.receivedSensorData != nil,
                color: .purple
            )
        }
    }

    // MARK: - Watch Connection Status

    private var watchConnectionStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: "applewatch")
                .font(.title2)
                .foregroundColor(connectivityManager.isWatchReachable ? .green : .gray)

            VStack(alignment: .leading, spacing: 2) {
                Text(connectivityManager.isWatchReachable ? "Apple Watch 연결됨" : "Apple Watch 연결 안 됨")
                    .font(.headline)
                    .foregroundColor(.white)

                if let lastUpdate = connectivityManager.lastUpdateTime {
                    Text("마지막 업데이트: \(lastUpdate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            Circle()
                .fill(connectivityManager.isWatchReachable ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(connectivityManager.isWatchReachable ? Color.green.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - GPS Signal Status

    private var gpsSignalStatus: some View {
        let location = connectivityManager.receivedLocation
        let accuracy = location?.horizontalAccuracy ?? -1

        // GPS 신호 강도 평가 (DistanceCalculator Extension 사용)
        let signalQuality = distanceCalculator.evaluateSignalQuality(location)
        let color = colorFromString(signalQuality.color)

        return HStack(spacing: 8) {
            Image(systemName: signalQuality.icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(signalQuality.text)
                    .font(.headline)
                    .foregroundColor(.white)

                if accuracy >= 0 {
                    Text("정확도: ±\(String(format: "%.1f", accuracy))m")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.5), lineWidth: 2)
                )
        )
    }

    // MARK: - Helper for Color Conversion

    // ═══════════════════════════════════════
    // PURPOSE: 문자열 색상명을 SwiftUI Color로 변환
    // PARAMETERS:
    //   - colorName: 색상명 ("gray", "green", "orange", "red")
    // RETURNS: 해당하는 SwiftUI Color
    // ═══════════════════════════════════════
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "gray": return .gray
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    // MARK: - Sensor Status

    private func sensorStatus(icon: String, name: String, isActive: Bool, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? color : .gray)

            Text(isActive ? "\(name) 활성" : "\(name) 비활성")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Circle()
                .fill(isActive ? color : Color.gray)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive ? color.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Workout Control Button

    private var workoutControlButton: some View {
        Button {
            if isWatchMonitoring {
                // 워치 운동 중지 및 기록 저장
                stopWorkoutMonitoring()
            } else {
                // 워치 운동 시작
                startWorkoutMonitoring()
            }
        } label: {
            Image(systemName: isWatchMonitoring ? "stop.circle.fill" : "play.circle.fill")
                .font(.title3)
                .foregroundColor(isWatchMonitoring ? .red : .green)
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button {
            if exporter.isRecording {
                // 녹화 중지 및 CSV 저장
                stopRecordingAndExport()
            } else {
                // 녹화 시작
                exporter.startRecording()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: exporter.isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.title3)
                    .foregroundColor(exporter.isRecording ? .red : .white)

                if exporter.isRecording {
                    Text("\(exporter.recordedCount)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 워치 운동 측정 시작
    // ═══════════════════════════════════════
    private func startWorkoutMonitoring() {
        guard connectivityManager.isWatchReachable else {
            alertMessage = "Apple Watch가 연결되지 않았습니다"
            showingAlert = true
            return
        }

        // Step 1: 시작 시간 기록
        monitoringStartTime = Date()

        // Step 2: Watch에 시작 명령 전송
        connectivityManager.sendCommand(.start)
        isWatchMonitoring = true

        // Step 3: CSV 녹화도 자동 시작
        exporter.startRecording()

        // Step 4: 실시간 케이던스 모니터링 시작 (타이머 및 버퍼 관리는 CadenceCalculator에서 수행)
        cadenceCalculator.startRealtimeMonitoring()

        // Step 5: 거리 계산기 초기화
        distanceCalculator.resetDistance()

        print("▶️ 워치 운동 측정 시작 (실시간 케이던스, 거리 계산 활성화)")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 워치 운동 측정 중지
    // ═══════════════════════════════════════
    private func stopWorkoutMonitoring() {
        // Step 1: Watch에 중지 명령 전송
        connectivityManager.sendCommand(.stop)
        isWatchMonitoring = false

        // Step 2: 실시간 모니터링 중지 (타이머 정지 및 버퍼 초기화는 CadenceCalculator에서 수행)
        cadenceCalculator.stopRealtimeMonitoring()

        // Step 3: 녹화 중지 및 전체 데이터 가져오기
        let data = exporter.stopRecording()

        // Step 4: 최종 케이던스 계산 및 업데이트 (전체 데이터 기반)
        if !data.isEmpty {
            cadenceCalculator.updateFinalCadence(from: data)
        }

        // Step 5: 알림 표시
        if !data.isEmpty {
            let cadenceText = cadenceCalculator.currentCadence > 0 ? String(format: "평균 케이던스: %.1f SPM\n", cadenceCalculator.currentCadence) : ""
            alertMessage = "측정이 완료되었습니다\n\(cadenceText)(\(data.count)개 샘플)"
            showingAlert = true
        }

        // Step 6: 상태 초기화
        monitoringStartTime = nil

        print("⏹️ 워치 운동 측정 중지")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 녹화 중지 및 CSV 파일 저장
    // ═══════════════════════════════════════
    private func stopRecordingAndExport() {
        let data = exporter.stopRecording()

        guard !data.isEmpty else {
            alertMessage = "저장할 데이터가 없습니다"
            showingAlert = true
            return
        }

        do {
            let fileURL = try exporter.exportToCSV(data: data)
            csvFileURL = fileURL
            showingShareSheet = true
        } catch {
            alertMessage = "CSV 파일 저장 실패: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
