import Foundation
import CoreLocation
import Combine

// Purpose: GPS 위치 데이터로부터 이동 거리 계산 및 관리
// MARK: - 함수 목록
/*
 * Distance Calculation
 * - addLocation(_:): 새 위치 추가 및 거리 계산
 * - resetDistance(): 거리 초기화
 * - calculateDistance(from:to:): 두 위치 간 거리 계산 (Haversine)
 *
 * Validation
 * - isValidLocation(_:): 위치 데이터 유효성 검증
 * - isRealisticSpeed(distance:time:): 속도 필터링
 *
 * 거리 계산 알고리즘:
 * 1. 연속된 GPS 좌표 수신
 * 2. 이전 위치와 현재 위치 간 거리 계산 (CLLocation.distance)
 * 3. 정확도 필터링 (horizontalAccuracy < 20m)
 * 4. 속도 필터링 (< 15 m/s = 54 km/h)
 * 5. 누적 거리 업데이트
 */

class DistanceCalculator: ObservableObject {

    // MARK: - Singleton

    static let shared = DistanceCalculator()

    // MARK: - Published Properties

    // Purpose: 누적 이동거리 (미터 단위)
    @Published var totalDistance: Double = 0.0

    // Purpose: 현재 속도 (m/s)
    @Published var currentSpeed: Double = 0.0

    // Purpose: 수집된 GPS 좌표 배열 (경로 표시용)
    @Published var locations: [CLLocationCoordinate2D] = []

    // MARK: - Private Properties

    // Purpose: 이전 위치 (거리 계산용)
    private var previousLocation: CLLocation?

    // Purpose: 최대 허용 정확도 (미터)
    private let maxHorizontalAccuracy: CLLocationAccuracy = 20.0

    // Purpose: 최대 허용 속도 (m/s) - 15 m/s = 54 km/h
    private let maxRealisticSpeed: Double = 15.0

    // MARK: - Initialization

    private init() {}

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
                self?.totalDistance += distance
                self?.currentSpeed = distance / timeDelta
            }

            print("📍 거리 업데이트: +\(String(format: "%.1f", distance))m (총: \(String(format: "%.2f", totalDistance / 1000))km)")
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

// MARK: - GPS Signal Quality Evaluation

extension DistanceCalculator {

    // Purpose: GPS 신호 품질 정보 (텍스트, 색상, 아이콘)
    struct SignalQuality {
        let text: String
        let color: String  // Color name for SwiftUI
        let icon: String
    }

    // ═══════════════════════════════════════
    // PURPOSE: GPS 신호 강도 평가
    // PARAMETERS:
    //   - location: 평가할 GPS 위치 (nil 가능)
    // RETURNS: SignalQuality (신호 품질 정보)
    // LOGIC:
    //   - horizontalAccuracy 기반 신호 강도 판단
    //   - < 0: 신호 없음 (회색)
    //   - < 10m: 매우 좋음 (녹색)
    //   - < 20m: 좋음 (녹색)
    //   - < 50m: 보통 (주황색)
    //   - >= 50m: 약함 (빨간색)
    // ═══════════════════════════════════════
    func evaluateSignalQuality(_ location: CLLocation?) -> SignalQuality {
        let accuracy = location?.horizontalAccuracy ?? -1

        if accuracy < 0 {
            return SignalQuality(text: "GPS 신호 없음", color: "gray", icon: "location.slash")
        } else if accuracy < 10 {
            return SignalQuality(text: "GPS 신호 매우 좋음", color: "green", icon: "location.fill")
        } else if accuracy < 20 {
            return SignalQuality(text: "GPS 신호 좋음", color: "green", icon: "location.fill")
        } else if accuracy < 50 {
            return SignalQuality(text: "GPS 신호 보통", color: "orange", icon: "location.fill")
        } else {
            return SignalQuality(text: "GPS 신호 약함", color: "red", icon: "location.fill")
        }
    }
}
