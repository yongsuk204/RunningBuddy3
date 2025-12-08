import Foundation

// Purpose: 캘리브레이션 데이터로부터 선형 회귀를 통해 보폭-케이던스 모델 계산
// MARK: - 함수 목록
/*
 * Linear Regression
 * - calculateStrideModel(from:): 여러 캘리브레이션 기록으로부터 α, β 계산
 * - predictStride(model:cadence:): 케이던스로 보폭 예측
 */

class StrideModelCalculator {

    // MARK: - Public Methods

    // ═══════════════════════════════════════
    // PURPOSE: 케이던스로 보폭 예측
    // PARAMETERS:
    //   - model: 선형 회귀 모델
    //   - cadence: 현재 케이던스 (spm)
    // RETURNS: 예측된 보폭 (미터)
    // ═══════════════════════════════════════
    static func predictStride(model: StrideData, cadence: Double) -> Double {
        return model.alpha * cadence + model.beta
    }

    // ═══════════════════════════════════════
    // PURPOSE: 선형 회귀를 통한 보폭-케이던스 모델 계산
    // PARAMETERS:
    //   - records: 캘리브레이션 기록 배열 (최소 2개 필요)
    // RETURNS: 계산된 선형 모델 (StrideData) 또는 nil
    // ALGORITHM:
    //   1. 최소 자승법(Ordinary Least Squares)으로 α, β 계산
    //   2. R² 값으로 모델 적합도 평가
    // FORMULA:
    //   stride = α * cadence + β
    //   α = Σ[(x-x̄)(y-ȳ)] / Σ[(x-x̄)²]
    //   β = ȳ - α*x̄
    // ═══════════════════════════════════════
    static func calculateStrideModel(from records: [CalibrationData]) -> StrideData? {
        // Step 1: 최소 5개 이상의 데이터 필요
        guard records.count >= 5 else {
            return nil
        }

        // Step 2: x = cadence, y = stride 데이터 추출
        let dataPoints: [(x: Double, y: Double)] = records.map { record in
            (x: record.averageCadence, y: record.averageStepLength)
        }

        // Step 3: 평균 계산
        let n = Double(dataPoints.count)
        let xMean = dataPoints.map { $0.x }.reduce(0, +) / n
        let yMean = dataPoints.map { $0.y }.reduce(0, +) / n

        // Step 4: α 계산 (기울기)
        // α = Σ[(xi - x̄)(yi - ȳ)] / Σ[(xi - x̄)²]
        let numerator = dataPoints.map { (x, y) in
            (x - xMean) * (y - yMean)
        }.reduce(0, +)

        let denominator = dataPoints.map { (x, _) in
            pow(x - xMean, 2)
        }.reduce(0, +)

        guard denominator > 0 else {
            print("⚠️ 선형 회귀 실패: 모든 케이던스 값이 동일함 (분산 = 0)")
            return nil
        }

        let alpha = numerator / denominator

        // Step 5: β 계산 (절편)
        // β = ȳ - α*x̄
        let beta = yMean - alpha * xMean

        // Step 6: R² 계산 (결정계수 - 모델 적합도)
        // R² = 1 - (SSres / SStot)
        // SSres = Σ(yi - ŷi)² (잔차 제곱합)
        // SStot = Σ(yi - ȳ)² (총 제곱합)
        let predictedValues = dataPoints.map { x, _ in
            alpha * x + beta
        }

        let ssRes = zip(dataPoints, predictedValues).map { (point, predicted) in
            pow(point.y - predicted, 2)
        }.reduce(0, +)

        let ssTot = dataPoints.map { _, y in
            pow(y - yMean, 2)
        }.reduce(0, +)

        let rSquared = ssTot > 0 ? (1 - ssRes / ssTot) : 0.0

        // Step 7: 모델 생성
        let model = StrideData(
            alpha: alpha,
            beta: beta,
            rSquared: rSquared,
            createdAt: Date(),
            sampleCount: records.count
        )
        return model
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: R² 값 해석
    // ═══════════════════════════════════════
    private static func interpretRSquared(_ rSquared: Double) -> String {
        switch rSquared {
        case 0.9...1.0: return "매우 우수"
        case 0.7..<0.9: return "우수"
        case 0.5..<0.7: return "보통"
        case 0.3..<0.5: return "낮음"
        default: return "매우 낮음"
        }
    }
}
