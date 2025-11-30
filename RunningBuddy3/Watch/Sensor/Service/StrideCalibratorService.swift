import Foundation
import CoreLocation
import Combine

// Purpose: NotificationCenter 이름 확장
extension Notification.Name {
    static let calibrationAutoComplete = Notification.Name("calibrationAutoComplete")
}

// Purpose: 100m 캘리브레이션 측정 세션 관리 서비스 (GPS 자동 100m 측정)
// MARK: - 함수 목록
/*
 * Session Management
 * - startCalibration(): 캘리브레이션 측정 시작 (GPS 거리 추적 시작)
 * - stopCalibration(): 캘리브레이션 측정 종료 및 결과 반환
 * - resetCalibration(): 캘리브레이션 데이터 초기화
 *
 * Data Collection
 * - addSensorData(_:): 센서 데이터 수집 (CadenceCalculator로 전달)
 * - addLocation(_:): GPS 위치 데이터 추가 (거리 계산용)
 */

class StrideCalibratorService: ObservableObject {

    // MARK: - Singleton

    static let shared = StrideCalibratorService()

    // MARK: - Published Properties

    // Purpose: 측정 진행 중 여부
    @Published var isCalibrating: Bool = false

    // Purpose: 측정 경과 시간 (초 단위)
    @Published var elapsedTime: Double = 0.0

    // Purpose: 현재 걸음 수 (실시간 업데이트)
    @Published var currentSteps: Int = 0

    // Purpose: 현재 케이던스 (실시간 업데이트)
    @Published var currentCadence: Double = 0.0

    // Purpose: 현재 GPS 거리 (실시간 업데이트, 미터 단위)
    @Published var currentDistance: Double = 0.0

    // Purpose: 100m 도달 여부
    @Published var hasReached100m: Bool = false

    // MARK: - Private Properties

    // Purpose: 측정 시작 시각
    private var startTime: Date?

    // Purpose: 캘리브레이션용 임시 DistanceCalculator
    private var tempDistanceCalculator: DistanceCalculator?

    // Purpose: 경과 시간 업데이트 타이머
    private var timer: Timer?

    // Purpose: Combine 구독 저장
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupBindings()
    }

    // MARK: - Setup

    // ═══════════════════════════════════════
    // PURPOSE: CadenceCalculator와 바인딩 설정
    // ═══════════════════════════════════════
    private func setupBindings() {
        // CadenceCalculator의 걸음 수와 케이던스를 구독
        CadenceCalculator.shared.$currentSteps
            .assign(to: \.currentSteps, on: self)
            .store(in: &cancellables)

        CadenceCalculator.shared.$currentCadence
            .assign(to: \.currentCadence, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 측정 시작
    // ═══════════════════════════════════════
    func startCalibration() {
        // Step 1: 측정 상태 초기화
        resetCalibration()

        // Step 2: 측정 시작
        isCalibrating = true
        startTime = Date()
        hasReached100m = false

        // Step 3: 임시 DistanceCalculator 생성 (GPS 거리 추적용)
        tempDistanceCalculator = DistanceCalculator()

        // Step 4: CadenceCalculator 실시간 모니터링 시작
        CadenceCalculator.shared.startRealtimeMonitoring()

        // Step 5: 경과 시간 업데이트 타이머 시작 (0.1초마다)
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }

            DispatchQueue.main.async {
                self.elapsedTime = Date().timeIntervalSince(startTime)

                // GPS 거리 업데이트 (임시 DistanceCalculator에서 가져옴)
                if let distance = self.tempDistanceCalculator?.totalDistance {
                    self.currentDistance = distance

                    // 100m 도달 시 자동 종료
                    if distance >= 100.0 && !self.hasReached100m {
                        self.hasReached100m = true
                        print("✅ 100m 도달! 측정 자동 종료")

                        // 자동 종료 (0.5초 후)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(name: .calibrationAutoComplete, object: nil)
                        }
                    }
                }
            }
        }

        print("▶️ 캘리브레이션 측정 시작 (GPS 자동 100m 측정)")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 측정 종료 및 결과 반환
    // RETURNS: CalibrationData (nil이면 유효하지 않은 측정)
    // ═══════════════════════════════════════
    func stopCalibration() -> CalibrationData? {
        // Step 1: 측정 상태 확인
        guard isCalibrating, let startTime = startTime else {
            print("⚠️ 측정이 시작되지 않았습니다")
            return nil
        }

        // Step 2: 타이머 중지
        timer?.invalidate()
        timer = nil

        // Step 3: CadenceCalculator 모니터링 중지
        CadenceCalculator.shared.stopRealtimeMonitoring()

        // Step 4: 최종 데이터 수집
        let finalTime = Date().timeIntervalSince(startTime)
        let finalSteps = currentSteps
        let finalCadence = currentCadence

        // Step 5: 측정 상태 종료
        isCalibrating = false

        // Step 6: 유효성 검증 (최소 20걸음, 10초 이상)
        guard finalSteps >= 20, finalTime >= 10.0 else {
            print("⚠️ 유효하지 않은 측정 데이터 (걸음 수: \(finalSteps), 시간: \(String(format: "%.1f", finalTime))초)")
            return nil
        }

        // Step 7: CalibrationData 생성
        let calibrationData = CalibrationData(
            totalSteps: finalSteps,
            averageCadence: finalCadence,
            timeSeconds: finalTime
        )

        print("✅ 캘리브레이션 측정 완료")
        print("   - 걸음 수: \(finalSteps)걸음")
        print("   - 평균 케이던스: \(String(format: "%.1f", finalCadence)) SPM")
        print("   - 소요 시간: \(String(format: "%.1f", finalTime))초")
        print("   - 평균 보폭: \(String(format: "%.2f", calibrationData.averageStepLength))m")

        return calibrationData
    }

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 데이터 초기화
    // ═══════════════════════════════════════
    func resetCalibration() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        elapsedTime = 0.0
        currentSteps = 0
        currentCadence = 0.0
        currentDistance = 0.0
        hasReached100m = false
        isCalibrating = false
        tempDistanceCalculator = nil

        print("🔄 캘리브레이션 데이터 초기화")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터 수집 (CadenceCalculator로 전달)
    // NOTE: Watch에서 전송된 센서 데이터를 CadenceCalculator로 전달
    // ═══════════════════════════════════════
    func addSensorData(_ data: SensorData) {
        guard isCalibrating else { return }
        CadenceCalculator.shared.addSensorData(data)
    }

    // ═══════════════════════════════════════
    // PURPOSE: GPS 위치 데이터 추가 (거리 계산용)
    // NOTE: Watch 또는 iPhone GPS에서 전송된 위치 데이터
    // ═══════════════════════════════════════
    func addLocation(_ location: CLLocation) {
        guard isCalibrating else { return }
        tempDistanceCalculator?.addLocation(location)
    }
}
