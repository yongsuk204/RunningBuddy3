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
 * Apple Watch Mounting Specification
 * - 장착 위치: 왼쪽 발목 안쪽 복사뼈 바로 위쪽
 * - 좌표계 (Device Frame):
 *   • +X축: 발바닥 방향 (수평면의 회전축)
 *   • +Y축: 정면 방향 (관상면의 회전축)
 *   • +Z축: 오른쪽 발 방향 (시상면의 회전축)
 *
 * Algorithm Overview
 * - 상태 머신으로 입각기 초반 피크 검출 (양수 → 첫 음수만)
 * - 주요 축: Gyro Z (발 회전), Accel Y (전후 스윙)
 * - SPM = (총 걸음 수 / 런닝 시간) × 60, 총 걸음 수 = (피크 수 - 1) × 2
 */

class CadenceCalculator: ObservableObject {

    // MARK: - Singleton

    static let shared = CadenceCalculator()

    // MARK: - Published Properties

    // Purpose: 현재 계산된 실시간 케이던스 (SPM - Steps Per Minute)
    @Published var currentCadence: Double = 0.0

    // Purpose: 누적 총 걸음 수 (양발 기준)
    @Published var currentSteps: Int = 0

    // MARK: - Private Properties

    // Purpose: 감지된 피크 타임스탬프 집합 (중복 카운팅 방지)
    private var detectedPeakTimestamps: Set<Date> = []

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
    // PURPOSE: 실시간 케이던스 모니터링 시작 (3초 간격 업데이트)
    // ═══════════════════════════════════════
    func startRealtimeMonitoring() {
        // Step 1: 기존 타이머 정리 및 버퍼 초기화
        stopRealtimeMonitoring()
        dataBuffer.removeAll()
        currentCadence = 0.0
        currentSteps = 0
        detectedPeakTimestamps.removeAll()

        // Step 2: 3초마다 실행되는 타이머 시작
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateIntervalSeconds, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Step 3: 현재 버퍼 데이터로 케이던스 계산 (걸음 수는 별도 계산)
            let cadence = self.calculateAverageCadence(from: self.dataBuffer)

            // Step 4: 새로운 피크만 감지하여 걸음 수 증가
            let peaks = self.detectPeaksWithCondition(data: self.dataBuffer)
            var newPeaksCount = 0

            for peakIndex in peaks {
                let timestamp = self.dataBuffer[peakIndex].timestamp

                // 이미 카운팅한 피크인지 확인
                if !self.detectedPeakTimestamps.contains(timestamp) {
                    self.detectedPeakTimestamps.insert(timestamp)
                    newPeaksCount += 1
                }
            }

            // Step 5: 새 피크가 있으면 누적 걸음 수 증가
            let stepIncrement = newPeaksCount * 2  // 양발 기준
            if stepIncrement > 0 {
                self.currentSteps += stepIncrement
            }

            DispatchQueue.main.async {
                self.currentCadence = cadence
            }

            print("📊 실시간 케이던스: \(String(format: "%.1f", cadence)) SPM, 총 걸음: \(self.currentSteps)걸음, 증가분: \(stepIncrement)걸음 (새 피크: \(newPeaksCount), 버퍼: \(self.dataBuffer.count)개)")
        }

        print("▶️ 실시간 케이던스 모니터링 시작")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터를 버퍼에 추가 (10초 슬라이딩 윈도우)
    // ═══════════════════════════════════════
    func addSensorData(_ data: SensorData) {
        dataBuffer.append(data)

        // 10초 이전 데이터 자동 제거
        let cutoffTime = Date().addingTimeInterval(-bufferWindowSeconds)
        dataBuffer.removeAll { $0.timestamp < cutoffTime }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 실시간 모니터링 중지 및 리소스 정리
    // ═══════════════════════════════════════
    func stopRealtimeMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
        dataBuffer.removeAll()

        print("⏹️ 실시간 케이던스 모니터링 중지")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 최종 케이던스 계산 및 UI 업데이트 (운동 종료 시 호출)
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
    // PURPOSE: 센서 데이터 배열에서 평균 케이던스 계산 (SPM, 양발 기준)
    // RETURNS: 평균 케이던스 (60~300 SPM 범위, 범위 외 0.0)
    // NOTE: 왼발 착용 기준 2배 보정, 완성된 피크 간격만 사용
    // ═══════════════════════════════════════
    func calculateAverageCadence(from sensorData: [SensorData]) -> Double {
        // Step 1: 데이터 충분성 확인 (최소 20개 = 1초 @ 20Hz)
        guard sensorData.count >= 20 else { return 0.0 }

        // Step 2: 입각기 초반 피크 검출 (상태 머신: 양수 → 첫 음수만)
        let peaks = detectPeaksWithCondition(data: sensorData)
        guard peaks.count >= 2 else { return 0.0 }

        // Step 3: 런닝 시간 계산 (첫 피크 ~ 마지막 피크, 초 단위)
        let runningTimeSeconds = sensorData[peaks.last!].timestamp
            .timeIntervalSince(sensorData[peaks.first!].timestamp)
        guard runningTimeSeconds > 0 else { return 0.0 }

        // Step 4: SPM 계산 (총 걸음 수 = (피크 수 - 1) × 2, SPM = 걸음 수 / 시간 × 60)
        let totalSteps = Double(peaks.count - 1) * 2.0
        let spm = (totalSteps / runningTimeSeconds) * 60.0

        // Step 5: 합리적인 범위 검증 (60 ~ 300 SPM)
        guard spm >= 60 && spm <= 300 else { return 0.0 }

        return spm
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 입각기 초반 피크 검출 (상태 머신: 양수 → 첫 음수만)
    // RETURNS: 피크 인덱스 배열
    // ═══════════════════════════════════════
    private func detectPeaksWithCondition(data: [SensorData]) -> [Int] {
        var peaks: [Int] = []

        enum DetectionState {
            case waitingPositive        // 양수 구간 대기 (Gyro Z > 0 AND Accel Y > 0)
            case waitingFirstNegative   // 첫 번째 음수 피크 대기 (Gyro Z <= -2.0)
            case ignoringUntilPositive  // 양수 복귀까지 무시
        }

        var state: DetectionState = .waitingPositive

        for i in 0..<data.count {
            let current = data[i]

            switch state {
            case .waitingPositive:
                if current.gyroscopeZ > 0 && current.accelerometerY > 0 {
                    state = .waitingFirstNegative
                }

            case .waitingFirstNegative:
                if current.gyroscopeZ <= -2.0 {
                    peaks.append(i)
                    state = .ignoringUntilPositive
                }

            case .ignoringUntilPositive:
                if current.gyroscopeZ > 0 {
                    state = .waitingPositive
                }
            }
        }

        return peaks
    }
}
