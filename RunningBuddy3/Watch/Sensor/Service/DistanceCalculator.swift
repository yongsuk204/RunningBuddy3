import Foundation
import CoreLocation
import Combine

// Purpose: GPS 기반 거리 계산 관리자
// MARK: - 함수 목록
/*
 * GPS Distance Calculation
 * - addLocation(_:): 새 위치 추가 및 GPS 거리 계산
 * - resetDistance(): 거리 초기화
 */

class DistanceCalculator: ObservableObject {

    // MARK: - Singleton

    static let shared = DistanceCalculator()

    // MARK: - Published Properties

    // Purpose: 누적 이동거리 (미터 단위)
    @Published var totalDistance: Double = 0.0

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
            print("⚠️ 부정확한 GPS 데이터 (accuracy: \(location.horizontalAccuracy)m)")
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
                print("⚠️ 비현실적 속도 감지 (\(String(format: "%.1f", distance / timeDelta)) m/s)")
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

            print("📍 GPS 거리 업데이트: +\(String(format: "%.1f", distance))m (총: \(String(format: "%.2f", totalDistance / 1000))km)")
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
        previousLocation = nil
        currentSpeed = 0.0
        locations.removeAll()

        print("🔄 거리 계산 초기화 (경로 데이터 삭제)")
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
