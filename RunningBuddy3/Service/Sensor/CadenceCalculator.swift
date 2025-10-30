import Foundation
import Combine

// Purpose: 센서 데이터로부터 케이던스(분당 스텝 수) 실시간 계산 및 관리
// MARK: - 함수 목록
/*
 * Real-time Monitoring
 * - startRealtimeMonitoring(): 실시간 케이던스 모니터링 시작 (3초마다 업데이트)
 * - addSensorData(_:): 센서 데이터를 버퍼에 추가 (10초 슬라이딩 윈도우)
 * - stopRealtimeMonitoring(): 실시간 모니터링 중지 및 버퍼 초기화
 * - updateFinalCadence(from:): 최종 케이던스 계산 및 업데이트 (전체 데이터셋 기반)
 *
 * Cadence Calculation
 * - calculateAverageCadence(from:): 센서 데이터 배열에서 평균 케이던스 계산 (SPM, 양발 기준)
 *
 * 발목 착용 기준 좌표계:
 * - X축: 수평면 축 (발바닥 방향이 +X) → 착지 충격 피크 검출
 * - Y축: 관상면 축 (몸 정면 방향이 +Y) → 전후 스윙 감지
 * - Z축: 시상면 축 (몸 중심 방향이 +Z) → 발 회전 감지
 *
 * 입각기 초반 감지 조건:
 * 1. X축 로컬 최대값 (착지 충격)
 * 2. X >= 1.5g (착지 임계값)
 * 3. Y < 0 (발이 앞으로 스윙 중)
 * 4. Gyroscope Z < 0 (발 뒤쪽 회전, 착지 순간)
 * 5. 최소 0.35초 간격 (노이즈 필터링)
 *
 * 계산 방법:
 * 1. 왼발 착지 피크 검출 (완성된 간격만 사용)
 * 2. 총 걸음 수 = (피크 수 - 1) × 2
 * 3. 런닝 시간 = 마지막 피크 - 첫 피크 (초)
 * 4. SPM = (총 걸음 수 / 런닝 시간) × 60
 */

class CadenceCalculator: ObservableObject {

    // MARK: - Singleton

    static let shared = CadenceCalculator()

    // MARK: - Published Properties

    // Purpose: 현재 계산된 실시간 케이던스 (SPM - Steps Per Minute)
    @Published var currentCadence: Double = 0.0

    // MARK: - Private Properties

    // Purpose: 실시간 케이던스 업데이트 타이머 (5초 간격)
    private var updateTimer: Timer?

    // Purpose: 실시간 케이던스 계산용 데이터 버퍼 (최근 10초 슬라이딩 윈도우)
    private var dataBuffer: [SensorData] = []

    // Purpose: 슬라이딩 윈도우 크기 (초 단위)
    private let bufferWindowSeconds: TimeInterval = 10.0

    // Purpose: 케이던스 업데이트 주기 (초 단위)
    private let updateIntervalSeconds: TimeInterval = 3.0

    private init() {}

    // MARK: - Real-time Monitoring

    // ═══════════════════════════════════════
    // PURPOSE: 실시간 케이던스 모니터링 시작
    // FUNCTIONALITY:
    //   - 3초마다 현재 버퍼 데이터로 케이던스 계산
    //   - @Published currentCadence 업데이트로 UI 자동 갱신
    // ═══════════════════════════════════════
    func startRealtimeMonitoring() {
        // Step 1: 기존 타이머 정리
        stopRealtimeMonitoring()

        // Step 2: 버퍼 초기화
        dataBuffer.removeAll()
        currentCadence = 0.0

        // Step 3: 3초마다 실행되는 타이머 시작
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateIntervalSeconds, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Step 4: 현재 버퍼 데이터로 케이던스 계산
            let calculatedCadence = self.calculateAverageCadence(from: self.dataBuffer)

            // Step 5: @Published 속성 업데이트 (UI 자동 갱신)
            DispatchQueue.main.async {
                self.currentCadence = calculatedCadence
            }

            // Step 6: 디버그 로그
            print("📊 실시간 케이던스: \(String(format: "%.1f", calculatedCadence)) SPM (\(self.dataBuffer.count)개 샘플)")
        }

        print("▶️ 실시간 케이던스 모니터링 시작")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터를 버퍼에 추가 및 슬라이딩 윈도우 관리
    // PARAMETERS:
    //   - data: 새로운 센서 데이터
    // FUNCTIONALITY:
    //   - 버퍼에 데이터 추가
    //   - 10초 이전 데이터 자동 제거 (슬라이딩 윈도우)
    // ═══════════════════════════════════════
    func addSensorData(_ data: SensorData) {
        // Step 1: 버퍼에 추가
        dataBuffer.append(data)

        // Step 2: 슬라이딩 윈도우 - 10초 이전 데이터 제거
        let cutoffTime = Date().addingTimeInterval(-bufferWindowSeconds)
        dataBuffer.removeAll { $0.timestamp < cutoffTime }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 실시간 모니터링 중지 및 리소스 정리
    // ═══════════════════════════════════════
    func stopRealtimeMonitoring() {
        // Step 1: 타이머 정지 및 해제
        updateTimer?.invalidate()
        updateTimer = nil

        // Step 2: 버퍼 초기화
        dataBuffer.removeAll()

        print("⏹️ 실시간 케이던스 모니터링 중지")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 최종 케이던스 계산 및 currentCadence 업데이트
    // PARAMETERS:
    //   - data: 전체 운동 세션의 센서 데이터
    // FUNCTIONALITY:
    //   - 전체 데이터셋으로 최종 평균 케이던스 계산
    //   - @Published currentCadence 업데이트로 UI에 최종 값 표시
    // NOTE: stopWorkoutMonitoring 시 호출하여 최종 결과 표시
    // ═══════════════════════════════════════
    func updateFinalCadence(from data: [SensorData]) {
        let finalCadence = calculateAverageCadence(from: data)

        DispatchQueue.main.async { [weak self] in
            self?.currentCadence = finalCadence
        }

        print("📊 최종 케이던스: \(String(format: "%.1f", finalCadence)) SPM (\(data.count)개 샘플)")
    }

    // MARK: - Cadence Calculation

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터 배열에서 평균 케이던스 계산
    // PARAMETERS:
    //   - sensorData: 센서 데이터 배열 (시간순 정렬 필요)
    // RETURNS: 평균 케이던스 (SPM - Steps Per Minute, 양발 기준)
    // ALGORITHM:
    //   1. X축 로컬 피크 검출 (X >= 1.5g, Y < 0, Gyro Z < 0)
    //   2. 완성된 간격 동안의 총 걸음 수 = (피크 수 - 1) × 2
    //   3. 런닝 시간 = 마지막 피크 - 첫 피크 (분 단위)
    //   4. SPM = 총 걸음 수 / 런닝 시간(분)
    // NOTE: 워치가 왼발 발목에만 착용되므로 2배 보정 필요
    // ═══════════════════════════════════════
    func calculateAverageCadence(from sensorData: [SensorData]) -> Double {
        // Step 1: 데이터 충분성 확인 (최소 20개 = 1초 @ 20Hz)
        guard sensorData.count >= 20 else {
            return 0.0
        }

        // Step 2: 입각기 초반 피크 검출 (X >= 1.5g, Y < 0, Gyro Z < 0)
        let peaks = detectPeaksWithCondition(data: sensorData)

        // Step 3: 피크가 2개 이상 있어야 간격 계산 가능
        guard peaks.count >= 2 else {
            return 0.0
        }

        // Step 4: 런닝 시간 계산 (첫 피크 ~ 마지막 피크, 초 단위)
        let runningTimeSeconds = sensorData[peaks.last!].timestamp
            .timeIntervalSince(sensorData[peaks.first!].timestamp)

        // Step 5: 시간이 0이면 계산 불가
        guard runningTimeSeconds > 0 else {
            return 0.0
        }

        // Step 6: 완성된 스텝 수 계산 (피크 간격 × 2)
        // 피크 4개 → 3개 완성된 간격 → 6걸음
        let totalSteps = Double(peaks.count - 1) * 2.0

        // Step 7: 분당 스텝 수 (SPM) 계산
        // SPM = (총 걸음 수 / 런닝 시간_초) × 60
        let spm = (totalSteps / runningTimeSeconds) * 60.0

        // Step 8: 합리적인 범위 검증 (60 ~ 300 SPM)
        guard spm >= 60 && spm <= 300 else {
            return 0.0  // 비정상 값 필터링
        }

        return spm
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 입각기 초반 조건으로 피크 검출
    // CONDITIONS:
    //   1. X축 로컬 최대값 (전후 데이터보다 큼)
    //   2. X >= 1.5g (착지 충격)
    //   3. Y < 0 (발이 앞으로 스윙 중)
    //   4. Gyroscope Z < 0 (발 뒤쪽 회전, 착지 순간)
    //   5. 이전 피크와 최소 0.35초 간격 (노이즈 필터링)
    // RETURNS: 피크 인덱스 배열
    // ═══════════════════════════════════════
    private func detectPeaksWithCondition(data: [SensorData]) -> [Int] {
        var peaks: [Int] = []
        var lastPeakTime: Date? = nil

        // Step 1: 양끝 제외하고 순회 (i-1, i+1 접근 필요)
        for i in 1..<(data.count - 1) {
            let current = data[i]
            let prev = data[i - 1]
            let next = data[i + 1]

            // Step 2: 로컬 최대값 확인
            guard prev.accelerometerX < current.accelerometerX &&
                  current.accelerometerX > next.accelerometerX else {
                continue
            }

            // Step 3: 조건 1 - X >= 1.5g (착지 충격)
            guard current.accelerometerX >= 1.5 else {
                continue
            }

            // Step 4: 조건 2 - Y < 0 (입각기 초반, 발이 앞으로 스윙)
            guard current.accelerometerY < 0 else {
                continue
            }

            // Step 5: 조건 3 - Gyro Z < 0 (발 뒤쪽 회전, 착지 순간)
            guard current.gyroscopeZ < 0 else {
                continue
            }

            // Step 6: 조건 4 - 최소 간격 0.35초 (노이즈 필터링)
            if let lastTime = lastPeakTime {
                let interval = current.timestamp.timeIntervalSince(lastTime)
                guard interval >= 0.35 else {
                    continue
                }
            }

            // Step 7: 모든 조건 통과 → 피크로 인정
            peaks.append(i)
            lastPeakTime = current.timestamp
        }

        return peaks
    }
}
