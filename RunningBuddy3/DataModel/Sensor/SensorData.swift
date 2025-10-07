import Foundation

// Purpose: Apple Watch 센서 데이터 모델 (iPhone과 Watch 앱 공유)
// MARK: - 함수 목록
/*
 * Computed Properties
 * - accelerometerMagnitude: 가속도계 3축 벡터 크기
 * - gyroscopeMagnitude: 자이로스코프 3축 벡터 크기
 *
 * Conversion Methods
 * - toDictionary(): WatchConnectivity 전송을 위한 딕셔너리 변환
 * - fromDictionary(_:): 딕셔너리에서 SensorData 객체 생성
 */

struct SensorData: Codable, Equatable {

    // MARK: - Properties

    // Purpose: 심박수 (bpm) - HealthKit에서 수집, 없을 수 있음
    let heartRate: Double?

    // Purpose: 가속도계 X축 (g)
    let accelerometerX: Double

    // Purpose: 가속도계 Y축 (g)
    let accelerometerY: Double

    // Purpose: 가속도계 Z축 (g)
    let accelerometerZ: Double

    // Purpose: 자이로스코프 X축 회전 속도 (rad/s)
    let gyroscopeX: Double

    // Purpose: 자이로스코프 Y축 회전 속도 (rad/s)
    let gyroscopeY: Double

    // Purpose: 자이로스코프 Z축 회전 속도 (rad/s)
    let gyroscopeZ: Double

    // Purpose: 데이터 측정 시간
    let timestamp: Date

    // MARK: - Computed Properties

    // ═══════════════════════════════════════
    // PURPOSE: 가속도계 3축 벡터 크기 계산 (√(x² + y² + z²))
    // ═══════════════════════════════════════
    var accelerometerMagnitude: Double {
        sqrt(
            pow(accelerometerX, 2) +
            pow(accelerometerY, 2) +
            pow(accelerometerZ, 2)
        )
    }

    // ═══════════════════════════════════════
    // PURPOSE: 자이로스코프 3축 벡터 크기 계산 (√(x² + y² + z²))
    // ═══════════════════════════════════════
    var gyroscopeMagnitude: Double {
        sqrt(
            pow(gyroscopeX, 2) +
            pow(gyroscopeY, 2) +
            pow(gyroscopeZ, 2)
        )
    }

    // MARK: - Conversion Methods

    // ═══════════════════════════════════════
    // PURPOSE: WatchConnectivity 전송을 위한 딕셔너리 변환
    // ═══════════════════════════════════════
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "accelerometerX": accelerometerX,
            "accelerometerY": accelerometerY,
            "accelerometerZ": accelerometerZ,
            "gyroscopeX": gyroscopeX,
            "gyroscopeY": gyroscopeY,
            "gyroscopeZ": gyroscopeZ,
            "timestamp": timestamp.timeIntervalSince1970
        ]

        // 심박수는 optional이므로 존재할 때만 추가
        if let heartRate = heartRate {
            dict["heartRate"] = heartRate
        }

        return dict
    }

    // ═══════════════════════════════════════
    // PURPOSE: 딕셔너리에서 SensorData 객체 생성
    // ═══════════════════════════════════════
    static func fromDictionary(_ dict: [String: Any]) -> SensorData? {
        // Step 1: 필수 값 추출
        guard let accelerometerX = dict["accelerometerX"] as? Double,
              let accelerometerY = dict["accelerometerY"] as? Double,
              let accelerometerZ = dict["accelerometerZ"] as? Double,
              let gyroscopeX = dict["gyroscopeX"] as? Double,
              let gyroscopeY = dict["gyroscopeY"] as? Double,
              let gyroscopeZ = dict["gyroscopeZ"] as? Double,
              let timestampInterval = dict["timestamp"] as? TimeInterval else {
            return nil
        }

        // Step 2: Optional 값 추출
        let heartRate = dict["heartRate"] as? Double

        // Step 3: SensorData 객체 생성
        return SensorData(
            heartRate: heartRate,
            accelerometerX: accelerometerX,
            accelerometerY: accelerometerY,
            accelerometerZ: accelerometerZ,
            gyroscopeX: gyroscopeX,
            gyroscopeY: gyroscopeY,
            gyroscopeZ: gyroscopeZ,
            timestamp: Date(timeIntervalSince1970: timestampInterval)
        )
    }
}
