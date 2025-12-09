import Foundation
import CoreLocation
import Combine

// Purpose: NotificationCenter 이름 확장
extension Notification.Name {
    static let calibrationAutoComplete = Notification.Name("calibrationAutoComplete")
}

// Purpose: 100m 캘리브레이션 측정 세션 관리
// MARK: - 함수 목록
/*
 * Session Management
 * - startCalibration(): 캘리브레이션 측정 시작 (DistanceCalculator.shared 사용)
 * - stopCalibration(): 캘리브레이션 측정 종료 및 결과 반환 (100m 전체 데이터 분석)
 * - resetCalibration(): 캘리브레이션 데이터 초기화
 *
 * Data Collection
 * - addSensorData(_:): 센서 데이터 수집 (100m 전체 평균 계산용)
 */

class CalibrationSession: ObservableObject {

    // MARK: - Singleton

    static let shared = CalibrationSession()

    // MARK: - Published Properties

    // Purpose: 측정 진행 중 여부
    @Published var isCalibrating: Bool = false

    // Purpose: 측정 경과 시간 (초 단위)
    @Published var elapsedTime: Double = 0.0

    // Purpose: 현재 GPS 거리 (실시간 업데이트, 미터 단위)
    @Published var currentDistance: Double = 0.0

    // Purpose: 100m 도달 여부
    @Published var hasReached100m: Bool = false

    // Purpose: 캘리브레이션 기록 배열 (시간순 정렬)
    @Published var calibrationRecords: [CalibrationData] = []

    // MARK: - Private Properties

    // Purpose: 측정 시작 시각
    private var startTime: Date?

    // Purpose: 경과 시간 업데이트 타이머
    private var timer: Timer?

    // Purpose: 100m 측정 동안 수집된 전체 센서 데이터 (평균 케이던스 계산용)
    private var allSensorData: [SensorData] = []

    // MARK: - Initialization

    private init() {}


    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 측정 시작
    // FUNCTIONALITY:
    //   - DistanceCalculator.shared 사용 (GPS 워밍업 완료된 인스턴스)
    //   - 측정 시작 전 거리 초기화
    //   - 센서 데이터 수집 (100m 전체 평균 계산용)
    //   - 100m 도달 시 자동 종료
    // ═══════════════════════════════════════
    func startCalibration() {
        // Step 1: 측정 상태 초기화
        resetCalibration()

        // Step 2: DistanceCalculator.shared 초기화 (새로운 측정 시작)
        DistanceCalculator.shared.resetDistance()

        // Step 3: 측정 시작
        isCalibrating = true
        startTime = Date()
        hasReached100m = false

        // Step 4: 경과 시간 업데이트 타이머 시작 (0.1초마다)
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }

            DispatchQueue.main.async {
                self.elapsedTime = Date().timeIntervalSince(startTime)

                // GPS 거리 업데이트 (DistanceCalculator.shared에서 가져옴)
                let distance = DistanceCalculator.shared.totalDistance
                self.currentDistance = distance

                // 100m 도달 시 자동 종료
                if distance >= 100.0 && !self.hasReached100m {
                    self.hasReached100m = true

                    // 자동 종료 알림 (0.5초 후)
                    // 👈 캘리브레이션뷰에 콜백으로 알려줌
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: .calibrationAutoComplete, object: nil)
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 측정 종료 및 결과 반환
    // RETURNS: CalibrationData (유효하지 않은 측정이면 nil)
    // VALIDATION: 최소 20걸음, 10초 이상 필요
    // ═══════════════════════════════════════
    func stopCalibration() -> CalibrationData? {
        guard isCalibrating, let startTime = startTime else {
            return nil
        }

        timer?.invalidate()
        timer = nil

        // 100m 전체 데이터로 최종 걸음 수 및 평균 케이던스 계산
        let finalTime = Date().timeIntervalSince(startTime)
        let finalSteps: Int
        let finalCadence: Double

        if !allSensorData.isEmpty {
            // 전체 센서 데이터로 정확한 걸음 수 및 평균 케이던스 계산
            finalCadence = CadenceCalculator.shared.calculateAverageCadence(from: allSensorData)

            // 걸음 수 계산: (피크 수 - 1) × 2
            let peaks = CadenceCalculator.shared.detectPeaksWithCondition(data: allSensorData)
            finalSteps = max(0, peaks.count - 1) * 2
        } else {
            isCalibrating = false
            return nil
        }

        isCalibrating = false

        // 유효성 검증 (최소 20걸음, 10초 이상)
        guard finalSteps >= 20, finalTime >= 10.0 else {
            return nil
        }

        let calibrationData = CalibrationData(
            totalSteps: finalSteps,
            averageCadence: finalCadence,
            timeSeconds: finalTime
        )
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
        currentDistance = 0.0
        hasReached100m = false
        isCalibrating = false
        allSensorData.removeAll()
    }

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터 수집 (100m 전체 평균 계산용)
    // ═══════════════════════════════════════
    func addSensorData(_ data: SensorData) {
        guard isCalibrating else { return }
        allSensorData.append(data)
    }
}
