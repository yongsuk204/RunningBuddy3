import Foundation
import CoreLocation

// Purpose: GPS 위치 데이터 모델 (iPhone과 Watch 앱 공유)
// MARK: - 함수 목록
/*
 * Conversion Methods
 * - toDictionary(): WatchConnectivity 전송을 위한 딕셔너리 변환
 * - fromDictionary(_:): 딕셔너리에서 GPSData 객체 생성
 * - toCLLocation(): CLLocation 객체로 변환
 */

struct GPSData: Codable, Equatable {

    // MARK: - Properties

    // Purpose: 위도 (degrees)
    let latitude: Double

    // Purpose: 경도 (degrees)
    let longitude: Double

    // Purpose: 고도 (meters)
    let altitude: Double

    // Purpose: 수평 정확도 (meters)
    let horizontalAccuracy: Double

    // Purpose: 수직 정확도 (meters)
    let verticalAccuracy: Double

    // Purpose: 속도 (m/s)
    let speed: Double

    // Purpose: 진행 방향 (degrees, 0 = North)
    let course: Double

    // Purpose: 측정 시간
    let timestamp: Date

    // MARK: - Initialization

    // ═══════════════════════════════════════
    // PURPOSE: 모든 프로퍼티로 GPSData 생성 (내부용)
    // ═══════════════════════════════════════
    init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double,
        verticalAccuracy: Double,
        speed: Double,
        course: Double,
        timestamp: Date
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.speed = speed
        self.course = course
        self.timestamp = timestamp
    }

    // ═══════════════════════════════════════
    // PURPOSE: CLLocation에서 GPSData 생성
    // ═══════════════════════════════════════
    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.speed = location.speed
        self.course = location.course
        self.timestamp = location.timestamp
    }

    // MARK: - Conversion Methods

    // ═══════════════════════════════════════
    // PURPOSE: WatchConnectivity 전송을 위한 딕셔너리 변환
    // ═══════════════════════════════════════
    func toDictionary() -> [String: Any] {
        return [
            "type": "location",
            "latitude": latitude,
            "longitude": longitude,
            "altitude": altitude,
            "horizontalAccuracy": horizontalAccuracy,
            "verticalAccuracy": verticalAccuracy,
            "speed": speed,
            "course": course,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }

    // ═══════════════════════════════════════
    // PURPOSE: 딕셔너리에서 GPSData 객체 생성
    // ═══════════════════════════════════════
    static func fromDictionary(_ dict: [String: Any]) -> GPSData? {
        // Step 1: 타입 확인
        guard let messageType = dict["type"] as? String,
              messageType == "location" else {
            return nil
        }

        // Step 2: 필수 값 추출
        guard let latitude = dict["latitude"] as? Double,
              let longitude = dict["longitude"] as? Double,
              let altitude = dict["altitude"] as? Double,
              let horizontalAccuracy = dict["horizontalAccuracy"] as? Double,
              let verticalAccuracy = dict["verticalAccuracy"] as? Double,
              let speed = dict["speed"] as? Double,
              let course = dict["course"] as? Double,
              let timestampInterval = dict["timestamp"] as? TimeInterval else {
            return nil
        }

        // Step 3: GPSData 객체 생성
        return GPSData(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            speed: speed,
            course: course,
            timestamp: Date(timeIntervalSince1970: timestampInterval)
        )
    }

    // ═══════════════════════════════════════
    // PURPOSE: CLLocation 객체로 변환
    // ═══════════════════════════════════════
    func toCLLocation() -> CLLocation {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        return CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
}
