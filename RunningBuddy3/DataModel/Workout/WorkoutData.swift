import Foundation

// Purpose: 운동 세션의 측정 데이터를 통합 관리하는 데이터 모델
// MARK: - 데이터 구조
/*
 * Workout Metrics
 * - distance: 이동 거리 (미터)
 * - duration: 운동 시간 (초)
 * - averageCadence: 평균 케이던스 (SPM)
 * - averageHeartRate: 평균 심박수 (BPM)
 * - averageSpeed: 평균 속도 (m/s)
 * - startTime: 운동 시작 시간
 * - endTime: 운동 종료 시간
 *
 * Computed Properties
 * - distanceInKm: 거리를 킬로미터로 변환
 * - averagePace: 평균 페이스 (분/km)
 * - formattedDuration: 운동 시간을 "HH:mm:ss" 형식으로 포맷
 */

struct WorkoutData: Codable {

    // MARK: - Properties

    // Purpose: 이동 거리 (미터)
    var distance: Double = 0.0

    // Purpose: 운동 시간 (초)
    var duration: TimeInterval = 0.0

    // Purpose: 평균 케이던스 (SPM - Steps Per Minute)
    var averageCadence: Double = 0.0

    // Purpose: 평균 심박수 (BPM - Beats Per Minute)
    var averageHeartRate: Double = 0.0

    // Purpose: 평균 속도 (m/s)
    var averageSpeed: Double = 0.0

    // Purpose: 운동 시작 시간
    var startTime: Date?

    // Purpose: 운동 종료 시간
    var endTime: Date?

    // MARK: - Computed Properties

    // ═══════════════════════════════════════
    // PURPOSE: 거리를 킬로미터로 변환
    // RETURNS: 킬로미터 단위 거리
    // ═══════════════════════════════════════
    var distanceInKm: Double {
        return distance / 1000.0
    }

    // ═══════════════════════════════════════
    // PURPOSE: 평균 페이스 계산 (분/km)
    // RETURNS: 1km 달리는 데 걸리는 시간 (분)
    // NOTE: 거리가 0이면 0 반환
    // ═══════════════════════════════════════
    var averagePace: Double {
        guard distanceInKm > 0 else { return 0.0 }
        return duration / 60.0 / distanceInKm
    }

    // ═══════════════════════════════════════
    // PURPOSE: 운동 시간을 "HH:mm:ss" 형식으로 포맷
    // RETURNS: 포맷된 시간 문자열
    // EXAMPLE: 3665초 → "01:01:05"
    // ═══════════════════════════════════════
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 페이스를 "분'초\"" 형식으로 포맷
    // RETURNS: 포맷된 페이스 문자열
    // EXAMPLE: 5.5분 → "5'30\""
    // ═══════════════════════════════════════
    var formattedPace: String {
        let totalSeconds = Int(averagePace * 60)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    // MARK: - Initialization

    // ═══════════════════════════════════════
    // PURPOSE: 기본 초기화 (모든 값 0)
    // ═══════════════════════════════════════
    init() {}

    // ═══════════════════════════════════════
    // PURPOSE: 전체 데이터로 초기화
    // ═══════════════════════════════════════
    init(
        distance: Double,
        duration: TimeInterval,
        averageCadence: Double,
        averageHeartRate: Double,
        averageSpeed: Double,
        startTime: Date?,
        endTime: Date?
    ) {
        self.distance = distance
        self.duration = duration
        self.averageCadence = averageCadence
        self.averageHeartRate = averageHeartRate
        self.averageSpeed = averageSpeed
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - WorkoutData Extension

extension WorkoutData {

    // ═══════════════════════════════════════
    // PURPOSE: 운동 데이터 요약 문자열 생성
    // RETURNS: 운동 데이터의 주요 지표를 포함한 문자열
    // ═══════════════════════════════════════
    func summary() -> String {
        return """
        📊 운동 요약
        ━━━━━━━━━━━━━━━━━━━━
        거리: \(String(format: "%.2f", distanceInKm)) km
        시간: \(formattedDuration)
        페이스: \(formattedPace) /km
        케이던스: \(String(format: "%.0f", averageCadence)) SPM
        심박수: \(String(format: "%.0f", averageHeartRate)) BPM
        속도: \(String(format: "%.2f", averageSpeed * 3.6)) km/h
        ━━━━━━━━━━━━━━━━━━━━
        """
    }
}
