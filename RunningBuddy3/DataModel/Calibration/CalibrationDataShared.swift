import Foundation
import FirebaseFirestore

// Purpose: 100m 캘리브레이션 측정 데이터 모델 (보폭 계산 정확도 향상)
// MARK: - 함수 목록
/*
 * Firestore Conversion
 * - toDictionary(): CalibrationData 객체를 Firestore 저장용 딕셔너리로 변환
 * - fromDictionary(_:): Firestore 문서 데이터에서 CalibrationData 객체 생성
 *
 * Calculation
 * - averageStepLength(): 평균 보폭 계산 (100m ÷ 걸음 수)
 */

struct CalibrationData: Codable {

    // MARK: - Properties

    // Purpose: 100m 측정 시 총 걸음 수 (양발 기준)
    let totalSteps: Int

    // Purpose: 100m 측정 시 평균 케이던스 (SPM - Steps Per Minute)
    let averageCadence: Double

    // Purpose: 100m 측정 소요 시간 (초 단위)
    let timeSeconds: Double

    // Purpose: 평균 보폭 (미터 단위, Firestore 저장용 stored property)
    let averageStepLength: Double

    // Purpose: 캘리브레이션 측정 날짜
    let measuredAt: Date

    // MARK: - Initialization

    init(totalSteps: Int, averageCadence: Double, timeSeconds: Double, measuredAt: Date = Date()) {
        self.totalSteps = totalSteps
        self.averageCadence = averageCadence
        self.timeSeconds = timeSeconds
        self.measuredAt = measuredAt

        // averageStepLength 계산 후 저장
        self.averageStepLength = totalSteps > 0 ? 100.0 / Double(totalSteps) : 0.0
    }

    // MARK: - Firestore Conversion

    // ═══════════════════════════════════════
    // PURPOSE: Firestore 저장을 위한 딕셔너리 변환
    // NOTE: averageStepLength를 명시적으로 저장 (선형회귀 모델용)
    // ═══════════════════════════════════════
    func toDictionary(userId: String) -> [String: Any] {
        return [
            "userId": userId,
            "totalSteps": totalSteps,
            "averageCadence": averageCadence,
            "timeSeconds": timeSeconds,
            "averageStepLength": averageStepLength,
            "measuredAt": Timestamp(date: measuredAt)
        ]
    }

    // ═══════════════════════════════════════
    // PURPOSE: Firestore 문서에서 CalibrationData 객체 생성
    // NOTE: averageStepLength는 stored property로 복원
    // ═══════════════════════════════════════
    static func fromDictionary(_ data: [String: Any]) -> CalibrationData? {
        guard let totalSteps = data["totalSteps"] as? Int,
              let averageCadence = data["averageCadence"] as? Double,
              let timeSeconds = data["timeSeconds"] as? Double,
              let timestamp = data["measuredAt"] as? Timestamp else {
            return nil
        }

        return CalibrationData(
            totalSteps: totalSteps,
            averageCadence: averageCadence,
            timeSeconds: timeSeconds,
            measuredAt: timestamp.dateValue()
        )
    }
}
