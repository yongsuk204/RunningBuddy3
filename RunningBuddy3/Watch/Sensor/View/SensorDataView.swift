import SwiftUI
import CoreLocation
import MapKit

// Purpose: iPhone에서 Apple Watch 센서 데이터 실시간 표시 - 지도 기반 레이아웃
// MARK: - 함수 목록
/*
 * View Components
 * - body: 메인 뷰 (지도 + 수치 오버레이)
 * - emptyMapView: GPS 데이터 없을 때 표시
 * - fullScreenMap: 전체 화면 지도 (경로 + 마커)
 * - metricsOverlay: 상단 상태 바 (팩토리 메서드 사용) + 하단 통합 수치 카드
 * - workoutControlButton: 운동 시작/중지 버튼
 * - recordButton: 데이터 기록 버튼
 *
 * Event Handlers
 * - handleDistanceTap(): 지도 모드 전환 (자동 → 수동 → 방향)
 * - startWorkoutMonitoring(): 워치 운동 측정 시작
 * - stopWorkoutMonitoring(): 워치 운동 측정 중지
 * - stopRecordingAndExport(): 기록 중지 및 CSV 내보내기
 *
 * Helper Methods
 * - updateCameraPosition(): 지도 카메라 위치 업데이트
 */
struct SensorDataView: View {

    // MARK: - Map Constants

    // Purpose: 지도 관련 상수 정의
    private enum MapConstants {
        static let gpsAccuracyThreshold: CLLocationAccuracy = 50.0  // GPS 정확도 임계값 (m)
        static let headingModeCameraDistance: CLLocationDistance = 1500  // 방향 모드 카메라 높이 (m)
        static let minimumMapSpan: CLLocationDegrees = 0.01  // 최소 지도 영역 (약 1km)
    }

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var connectivityManager = PhoneConnectivityManager.shared
    @StateObject private var exporter = SensorDataExporter()
    @StateObject private var cadenceCalculator = CadenceCalculator.shared
    @StateObject private var distanceCalculator = DistanceCalculator.shared
    @StateObject private var headingManager = HeadingManager.shared

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

    // Purpose: 지도 카메라 위치
    @State private var cameraPosition: MapCameraPosition = .automatic

    // Purpose: 현재 지도 모드
    @State private var mapMode: MapMode = .automatic

    // Purpose: 프로그래밍 방식 카메라 업데이트 플래그 (사용자 조작과 구분)
    @State private var isProgrammaticCameraUpdate = false

    // MARK: - Computed Properties

    // Purpose: GPS 좌표 배열
    private var locations: [CLLocationCoordinate2D] {
        distanceCalculator.locations
    }

    // Purpose: 시작 위치
    private var startLocation: CLLocationCoordinate2D? {
        locations.first
    }

    // Purpose: 현재 위치
    private var currentLocation: CLLocationCoordinate2D? {
        locations.last
    }

    // Purpose: GPS 신호 활성 상태 (정확도 임계값 이내)
    private var isGPSActive: Bool {
        guard let location = connectivityManager.receivedLocation,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= MapConstants.gpsAccuracyThreshold else {
            return false
        }
        return true
    }

    // Purpose: 지도 영역 계산 (한 번의 순회로 최적화)
    private var mapRegion: MKCoordinateRegion? {
        guard !locations.isEmpty else { return nil }

        // Step 1: 한 번의 순회로 min/max 계산 (O(n))
        var minLat = Double.infinity
        var maxLat = -Double.infinity
        var minLon = Double.infinity
        var maxLon = -Double.infinity

        for location in locations {
            minLat = min(minLat, location.latitude)
            maxLat = max(maxLat, location.latitude)
            minLon = min(minLon, location.longitude)
            maxLon = max(maxLon, location.longitude)
        }

        // Step 2: 중심점 및 영역 계산
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let latDelta = (maxLat - minLat) * 1.5
        let lonDelta = (maxLon - minLon) * 1.5

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, MapConstants.minimumMapSpan),
                longitudeDelta: max(lonDelta, MapConstants.minimumMapSpan)
            )
        )
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .navigationTitle("실시간 센서")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    workoutControlButton
                }

                ToolbarItem(placement: .topBarTrailing) {
                    recordButton
                }
            }
            .onChange(of: connectivityManager.receivedSensorData) { oldValue, newValue in
                handleSensorDataChange(newValue)
            }
            .onChange(of: connectivityManager.receivedLocation) { oldValue, newValue in
                handleLocationChange(newValue)
            }
            .onChange(of: locations.count) { oldValue, newValue in
                updateCameraPosition()
            }
            .onChange(of: headingManager.currentHeading) { oldValue, newValue in
                handleHeadingChange()
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
                handleViewAppear()
            }
            .onDisappear {
                handleViewDisappear()
            }
    }

    private var mainContent: some View {
        ZStack {
            // 배경 그라데이션
            Color.clear
                .appGradientBackground()

            // 전체 화면 지도
            if locations.isEmpty {
                emptyMapView
            } else {
                fullScreenMap
            }

            // 수치 오버레이
            metricsOverlay
        }
    }

    // MARK: - Empty Map View

    private var emptyMapView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))

            Text("GPS 데이터 수집 중...")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))

            Text("운동을 시작하면 경로가 표시됩니다")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Full Screen Map

    private var fullScreenMap: some View {
        Map(position: $cameraPosition) {
            // 경로 폴리라인
            if locations.count > 1 {
                MapPolyline(coordinates: locations)
                    .stroke(.blue, lineWidth: 4)
            }

            // 시작 위치 마커
            if let start = startLocation {
                Annotation("시작", coordinate: start) {
                    ZStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 30, height: 30)

                        Image(systemName: "figure.run")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
            }

            // 현재 위치 마커
            if let current = currentLocation,
               let start = startLocation,
               current.latitude != start.latitude || current.longitude != start.longitude {
                Annotation("현재", coordinate: current) {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )

                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onMapCameraChange(frequency: .onEnd) { _ in
            // 사용자가 지도를 조작했을 때만 수동 모드로 전환
            // (프로그래밍 방식 업데이트는 무시)
            if !isProgrammaticCameraUpdate && (mapMode == .automatic || mapMode == .heading) {
                mapMode = .manual
                headingManager.stopUpdatingHeading()
                print("📍 사용자 조작 감지 → 수동 모드 전환")
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Metrics Overlay

    private var metricsOverlay: some View {
        VStack(spacing: 0) {
            // 상단: 컴팩트 상태 바
            HStack(spacing: 8) {
                Spacer()

                CompactStatusCard.watchStatus(
                    isReachable: connectivityManager.isWatchReachable
                )

                CompactStatusCard.gpsStatus(
                    location: connectivityManager.receivedLocation,
                    isActive: isGPSActive
                )

                Spacer()
            }

            Spacer()

            // 하단: 보폭 추정 거리 카드 (간단한 버전)
            HStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.title2)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("보폭 추정 거리")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    if !StrideCalibratorService.shared.calibrationRecords.isEmpty {
                        Text(String(format: "%.2f km", distanceCalculator.strideBasedDistance / 1000.0))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        Text("캘리브레이션 필요")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal)
            .padding(.bottom, 8)

            // 하단: 통합 수치 카드
            UnifiedMetricsCard(
                heartRate: connectivityManager.receivedSensorData?.heartRate,
                cadence: cadenceCalculator.currentCadence,
                distance: distanceCalculator.totalDistance,
                mapMode: mapMode,
                onDistanceTap: handleDistanceTap
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Workout Control Button

    private var workoutControlButton: some View {
        Button {
            if isWatchMonitoring {
                stopWorkoutMonitoring()
            } else {
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
                stopRecordingAndExport()
            } else {
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

    // MARK: - Metric Button Handlers

    // Purpose: 거리 버튼 탭 핸들러 (지도 모드 순환: 자동 → 수동 → 방향 → 자동)
    private func handleDistanceTap() {
        withAnimation {
            // Step 1: 다음 모드로 전환
            mapMode = mapMode.next

            // Step 2: heading 업데이트 관리
            if mapMode == .heading {
                // 방향 모드로 전환 시 나침반 업데이트 시작
                headingManager.startUpdatingHeading()
            } else {
                // 다른 모드로 전환 시 나침반 업데이트 중지
                headingManager.stopUpdatingHeading()
            }

            // Step 3: 자동 또는 방향 모드일 때 현재 위치로 이동
            if mapMode == .automatic || mapMode == .heading {
                updateCameraPosition()
            }
        }
        print("📍 지도 모드 변경: \(mapMode.description)")
    }

    // MARK: - Helper Methods

    private func updateCameraPosition() {
        // Step 1: 프로그래밍 방식 업데이트임을 표시
        isProgrammaticCameraUpdate = true

        // Step 2: 모드에 따라 카메라 위치 업데이트
        switch mapMode {
        case .automatic:
            // 자동 모드 - 경로 전체를 보여주는 region
            if let region = mapRegion {
                cameraPosition = .region(region)
            }

        case .manual:
            // 수동 모드 - 카메라 업데이트 안 함 (사용자가 원하는 위치 유지)
            break

        case .heading:
            // 방향 모드 - 현재 위치를 중심으로 사용자가 바라보는 방향에 맞춰 지도 표시
            if let current = currentLocation {
                let rawHeading = headingManager.currentHeading
                let adjustedHeading = (rawHeading).truncatingRemainder(dividingBy: 360)

                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: current,
                        distance: MapConstants.headingModeCameraDistance,
                        heading: adjustedHeading
                    )
                )

                print("🧭 Heading \(String(format: "%.0f", rawHeading))°")
            }
        }

        // Step 3: 카메라 애니메이션 완료 후 플래그 해제 (약 300ms 대기)
        // Note: 지도 애니메이션 완료를 보장하기 위한 고정 딜레이
        // TODO: iOS 17+에서 withAnimation completion handler 사용 고려
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            isProgrammaticCameraUpdate = false
        }
    }

    private func startWorkoutMonitoring() {
        guard connectivityManager.isWatchReachable else {
            alertMessage = "Apple Watch가 연결되지 않았습니다"
            showingAlert = true
            return
        }

        connectivityManager.sendCommand(.start)
        isWatchMonitoring = true
        mapMode = .automatic // 운동 시작 시 자동 모드로 설정
        exporter.startRecording()
        cadenceCalculator.startRealtimeMonitoring()
        distanceCalculator.resetDistance()

        print("▶️ 워치 운동 측정 시작")
    }

    private func stopWorkoutMonitoring() {
        connectivityManager.sendCommand(.stop)
        isWatchMonitoring = false
        cadenceCalculator.stopRealtimeMonitoring()

        let data = exporter.stopRecording()

        if !data.isEmpty {
            cadenceCalculator.updateFinalCadence(from: data)

            let cadenceText = cadenceCalculator.currentCadence > 0 ? String(format: "평균 케이던스: %.1f SPM\n", cadenceCalculator.currentCadence) : ""
            alertMessage = "측정이 완료되었습니다\n\(cadenceText)(\(data.count)개 샘플)"
            showingAlert = true
        }

        print("⏹️ 워치 운동 측정 중지")
    }

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

    // MARK: - Event Handlers

    private func handleSensorDataChange(_ data: SensorData?) {
        if let data = data {
            exporter.addSensorData(data)
            cadenceCalculator.addSensorData(data)
        }
    }

    private func handleLocationChange(_ location: CLLocation?) {
        if let location = location {
            distanceCalculator.addLocation(location)
        }
    }

    private func handleHeadingChange() {
        // 방향 모드일 때만 heading 변화에 따라 카메라 업데이트
        if mapMode == .heading {
            updateCameraPosition()
        }
    }

    private func handleViewAppear() {
        print("📱 SensorDataView 진입 - Watch 연결 상태: \(connectivityManager.isWatchReachable)")
        // 캘리브레이션 모델은 MainAppView에서 자동 로드됨
    }

    private func handleViewDisappear() {
        // 뷰가 사라질 때 heading 업데이트 중지
        headingManager.stopUpdatingHeading()
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

// MARK: - Preview

#Preview("SensorDataView") {
    NavigationStack {
        SensorDataView()
    }
}
