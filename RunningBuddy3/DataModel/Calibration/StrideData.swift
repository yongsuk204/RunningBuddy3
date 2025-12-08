import Foundation
import FirebaseFirestore

// Purpose: 선형 회귀 모델 데이터 (보폭-케이던스 관계)
// MARK: - 함수 목록
/*
 * Firestore Conversion
 * - toDictionary(): StrideData 객체를 Firestore 저장용 딕셔너리로 변환
 * - fromDictionary(_:): Firestore 문서 데이터에서 StrideData 객체 생성
 */

/// 선형 회귀 모델: stride = alpha * cadence + beta
struct StrideData: Codable {

    // MARK: - Properties

    // Purpose: 케이던스 계수 (미터/spm) - 일반적으로 음수값
    let alpha: Double

    // Purpose: 절편 (미터)
    let beta: Double

    // Purpose: 결정계수 (R²) - 모델 적합도 (0~1, 1에 가까울수록 정확)
    let rSquared: Double

    // Purpose: 모델 생성 시각
    let createdAt: Date

    // Purpose: 모델 학습에 사용된 캘리브레이션 기록 수
    let sampleCount: Int

    // MARK: - Firestore Conversion

    // ═══════════════════════════════════════
    // PURPOSE: Firestore 저장을 위한 딕셔너리 변환
    // ═══════════════════════════════════════
    func toDictionary() -> [String: Any] {
        return [
            "alpha": alpha,
            "beta": beta,
            "rSquared": rSquared,
            "createdAt": Timestamp(date: createdAt),
            "sampleCount": sampleCount
        ]
    }

    // ═══════════════════════════════════════
    // PURPOSE: Firestore 문서에서 StrideData 객체 생성
    // ═══════════════════════════════════════
    static func fromDictionary(_ data: [String: Any]) -> StrideData? {
        guard let alpha = data["alpha"] as? Double,
              let beta = data["beta"] as? Double,
              let rSquared = data["rSquared"] as? Double,
              let timestamp = data["createdAt"] as? Timestamp,
              let sampleCount = data["sampleCount"] as? Int else {
            return nil
        }

        return StrideData(
            alpha: alpha,
            beta: beta,
            rSquared: rSquared,
            createdAt: timestamp.dateValue(),
            sampleCount: sampleCount
        )
    }
}
