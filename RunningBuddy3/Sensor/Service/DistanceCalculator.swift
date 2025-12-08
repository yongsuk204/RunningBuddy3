import Foundation
import CoreLocation
import Combine

// Purpose: GPS 기반 거리 계산 및 동적 보폭 추정 거리 관리자
// MARK: - 함수 목록
/*
 * GPS Distance Calculation
 * - addLocation(_:): 새 위치 추가 및 GPS 거리 계산
 * - resetDistance(): 거리 초기화
 *
 * Stride-Based Distance Estimation (Dynamic)
 * - setStrideModel(_:): 선형 회귀 모델 설정
 * - updateSteps(_:currentCadence:): 걸음 수 및 케이던스로 동적 보폭 계산
 */

class DistanceCalculator: ObservableObject {

    // MARK: - Singleton

    static let shared = DistanceCalculator()

    // MARK: - Published Properties

    // Purpose: 누적 이동거리 (미터 단위) - GPS 기반
    @Published var totalDistance: Double = 0.0

    // Purpose: 보폭 추정 거리 (미터 단위) - 걸음 수 × 평균 보폭
    @Published var strideBasedDistance: Double = 0.0

    // ════════════════════════════════════════════════════════════════════
    // 🔮 [FUTURE] 페이스 표시 기능용 (향후 사용 예정)
    // ════════════════════════════════════════════════════════════════════
    // Purpose: 현재 속도 (m/s) - 페이스 계산에 사용 가능 (속도 역수 = 분/km)
    @Published var currentSpeed: Double = 0.0
    // ════════════════════════════════════════════════════════════════════

    // Purpose: 수집된 GPS 좌표 배열 (경로 표시용)
    @Published var locations: [CLLocationCoordinate2D] = []

    // MARK: - Private Properties (GPS)

    // Purpose: 이전 위치 (거리 계산용)
    private var previousLocation: CLLocation?

    // Purpose: 최대 허용 정확도 (미터)
    private let maxHorizontalAccuracy: CLLocationAccuracy = 20.0

    // Purpose: 최대 허용 속도 (m/s) - 15 m/s = 54 km/h
    private let maxRealisticSpeed: Double = 15.0

    // MARK: - Private Properties (Stride-Based)

    // Purpose: 선형 회귀 모델 (보폭 = α * 케이던스 + β)
    private var strideModel: StrideData?

    // Purpose: 이전 걸음 수 (증가분 계산용)
    private var previousSteps: Int = 0

    // MARK: - Initialization

    // Purpose: Singleton과 임시 인스턴스 생성을 위한 initializer (internal)
    // NOTE: StrideCalibratorService에서 임시 GPS 거리 추적용으로 사용
    init() {}

    // MARK: - Public Methods

    // ═══════════════════════════════════════
    // PURPOSE: 새 위치 추가 및 거리 계산
    // PARAMETERS:
    //   - location: 새로운 GPS 위치
    // FUNCTIONALITY:
    //   - 위치 유효성 검증
    //   - 이전 위치와의 거리 계산
    //   - 속도 필터링
    //   - 누적 거리 업데이트
    // ═══════════════════════════════════════
    func addLocation(_ location: CLLocation) {
        // Step 1: 위치 유효성 검증
        guard isValidLocation(location) else {
            return
        }

        // Step 2: 이전 위치가 있으면 거리 계산
        if let previous = previousLocation {
            // 두 GPS 좌표 간 거리 계산 (Haversine 공식 내장)
            let distance = calculateDistance(from: previous, to: location)

            // Step 3: 시간 간격 계산
            let timeDelta = location.timestamp.timeIntervalSince(previous.timestamp)

            // Step 4: 속도 필터링 (순간이동 방지)
            guard isRealisticSpeed(distance: distance, time: timeDelta) else {
                previousLocation = location
                return
            }

            // Step 5: 누적 거리 업데이트
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.totalDistance += distance
                // 페이스 표시 기능용 (향후 사용 예정)
                self.currentSpeed = distance / timeDelta
            }
        }

        // Step 6: 현재 위치를 이전 위치로 저장
        previousLocation = location

        // Step 7: 유효한 좌표를 배열에 추가 (경로 표시용)
        DispatchQueue.main.async { [weak self] in
            self?.locations.append(location.coordinate)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 거리 초기화
    // ═══════════════════════════════════════
    func resetDistance() {
        totalDistance = 0.0
        strideBasedDistance = 0.0
        previousLocation = nil
        currentSpeed = 0.0
        locations.removeAll()
        previousSteps = 0
    }

    // ═══════════════════════════════════════
    // PURPOSE: 선형 회귀 모델 설정
    // PARAMETERS:
    //   - model: 선형 회귀 모델 (보폭 = α * 케이던스 + β)
    // ═══════════════════════════════════════
    func setStrideModel(_ model: StrideData?) {
        self.strideModel = model
    }

    // ═══════════════════════════════════════
    // PURPOSE: 걸음 수 및 케이던스로 동적 보폭 기반 거리 계산
    // PARAMETERS:
    //   - currentSteps: 현재 누적 걸음 수
    //   - currentCadence: 현재 케이던스 (spm)
    // FUNCTIONALITY:
    //   1. 걸음 수 증가분 계산
    //   2. 현재 케이던스로 보폭 예측 (선형 모델)
    //   3. 증가분 × 예측 보폭 = 추가 거리
    //   4. 보폭 추정 거리 누적
    // ═══════════════════════════════════════
    func updateSteps(_ currentSteps: Int, currentCadence: Double) {
        // Step 1: 모델 확인
        guard let model = strideModel else { return }

        // Step 2: 걸음 수 증가분 계산
        let stepIncrement = currentSteps - previousSteps
        guard stepIncrement > 0 else { return }

        // Step 3: 현재 보폭 예측 (동적 보폭: stride = α * cadence + β)
        let predictedStride = StrideModelCalculator.predictStride(model: model, cadence: currentCadence)

        // Step 4: 추가 거리 계산
        let addedDistance = Double(stepIncrement) * predictedStride

        // Step 5: 누적 거리 업데이트
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.strideBasedDistance += addedDistance
        }

        previousSteps = currentSteps
    }

    // MARK: - Private Methods

    // ═══════════════════════════════════════
    // PURPOSE: 두 위치 간 거리 계산
    // PARAMETERS:
    //   - from: 시작 위치
    //   - to: 도착 위치
    // RETURNS: 거리 (미터)
    // NOTE: CLLocation의 distance(from:) 사용 (Haversine 공식 내장)
    // ═══════════════════════════════════════
    private func calculateDistance(from: CLLocation, to: CLLocation) -> Double {
        return to.distance(from: from)
    }

    // ═══════════════════════════════════════
    // PURPOSE: 위치 데이터 유효성 검증
    // PARAMETERS:
    //   - location: 검증할 위치 데이터
    // RETURNS: 유효하면 true, 아니면 false
    // CONDITIONS:
    //   1. horizontalAccuracy > 0 (유효한 측정값)
    //   2. horizontalAccuracy < 20m (충분한 정확도)
    // ═══════════════════════════════════════
    private func isValidLocation(_ location: CLLocation) -> Bool {
        return location.horizontalAccuracy > 0 &&
               location.horizontalAccuracy < maxHorizontalAccuracy
    }

    // ═══════════════════════════════════════
    // PURPOSE: 속도 필터링 (비현실적 이동 제외)
    // PARAMETERS:
    //   - distance: 이동 거리 (미터)
    //   - time: 경과 시간 (초)
    // RETURNS: 현실적인 속도면 true, 아니면 false
    // NOTE: 15 m/s (54 km/h) 이하만 허용
    // ═══════════════════════════════════════
    private func isRealisticSpeed(distance: Double, time: TimeInterval) -> Bool {
        guard time > 0 else { return false }

        let speed = distance / time
        return speed < maxRealisticSpeed
    }
}
