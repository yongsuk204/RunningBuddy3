import Foundation
import HealthKit
import CoreMotion
import Combine

// Purpose: Apple Watch에서 센서 데이터 실시간 수집 (심박수, 가속도계, 자이로스코프) - 이벤트 기반 즉시 전송
// MARK: - 함수 목록
/*
 * Monitoring Control
 * - startMonitoring(): 센서 모니터링 시작 (이벤트 기반)
 * - stopMonitoring(): 센서 모니터링 중지
 *
 * Heart Rate Monitoring
 * - startHeartRateStreaming(): HealthKit을 사용한 심박수 실시간 스트리밍
 * - processHeartRateSamples(_:): 심박수 샘플 처리 및 센서 데이터 업데이트
 * - stopHeartRateStreaming(): 심박수 스트리밍 중지
 *
 * Motion Monitoring
 * - startMotionUpdates(): CoreMotion을 사용한 가속도계/자이로스코프 데이터 수집 (이벤트 기반)
 * - stopMotionUpdates(): 모션 센서 업데이트 중지
 *
 * Sensor Data Update
 * - createAndPublishSensorData(motion:): 센서 데이터 생성 및 게시 (이벤트 기반 즉시 업데이트)
 *
 * Permission Handling
 * - requestHealthKitAuthorization(): HealthKit 권한 요청
 */

class WatchSensorManager: ObservableObject {

    // MARK: - Published Properties

    // Purpose: 현재 센서 데이터
    @Published var currentSensorData: SensorData?

    // Purpose: 모니터링 상태
    @Published var isMonitoring = false

    // Purpose: 현재 심박수 (UI 표시용)
    @Published var currentHeartRate: Double?

    // Purpose: 에러 메시지
    @Published var errorMessage: String?

    // MARK: - Private Properties

    // Purpose: HealthKit 스토어
    private let healthStore = HKHealthStore()

    // Purpose: CoreMotion 매니저 (Shared instance 사용 - 앱당 하나의 인스턴스만 사용해야 함)
    private static let sharedMotionManager: CMMotionManager = {
        let manager = CMMotionManager()
        manager.accelerometerUpdateInterval = 0.1
        manager.gyroUpdateInterval = 0.1
        return manager
    }()

    private let motionManager = WatchSensorManager.sharedMotionManager

    // Purpose: 심박수 쿼리 (스트리밍 중지를 위해 저장)
    private var heartRateQuery: HKQuery?

    // Purpose: 최근 디바이스 모션 데이터 (가속도계 + 자이로스코프 통합)
    private var latestDeviceMotion: CMDeviceMotion?

    // MARK: - Initialization

    init() {
        // CMMotionManager는 shared instance 사용
    }

    // MARK: - Monitoring Control

    // ═══════════════════════════════════════
    // PURPOSE: 센서 모니터링 시작
    // ═══════════════════════════════════════
    func startMonitoring() async {
        // Step 1: HealthKit 권한 요청
        do {
            try await requestHealthKitAuthorization()
        } catch {
            await MainActor.run {
                errorMessage = "HealthKit 권한 요청 실패: \(error.localizedDescription)"
            }
            print("❌ HealthKit 권한 요청 실패: \(error)")
            // HealthKit 실패해도 모션 센서는 사용 가능
        }

        // Step 2: 심박수 스트리밍 시작
        startHeartRateStreaming()

        // Step 3: 모션 센서 시작 (이벤트 기반 실시간 업데이트)
        startMotionUpdates()

        // Step 4: 모니터링 상태 업데이트
        await MainActor.run {
            isMonitoring = true
        }

        print("✅ 센서 모니터링 시작 (이벤트 기반)")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 센서 모니터링 중지
    // ═══════════════════════════════════════
    func stopMonitoring() {
        // Step 1: UI 상태 즉시 업데이트 (사용자 응답성 우선)
        isMonitoring = false
        currentSensorData = nil
        currentHeartRate = nil

        // Step 2: 센서 중지 작업은 Task로 백그라운드 처리 (메인 액터 컨텍스트 유지)
        Task { [weak self] in
            await self?.performSensorCleanup()
        }

        print("⏹️ 센서 모니터링 중지 (UI 즉시 반영)")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 센서 정리 작업 (백그라운드에서 안전하게 실행)
    // ═══════════════════════════════════════
    @MainActor
    private func performSensorCleanup() async {
        stopHeartRateStreaming()
        stopMotionUpdates()
    }

    // MARK: - Heart Rate Monitoring

    // ═══════════════════════════════════════
    // PURPOSE: HealthKit을 사용한 심박수 실시간 스트리밍
    // ═══════════════════════════════════════
    private func startHeartRateStreaming() {
        // Step 1: 심박수 타입 정의
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            DispatchQueue.main.async {
                self.errorMessage = "심박수 타입을 찾을 수 없습니다"
            }
            return
        }

        // Step 2: 스트리밍 쿼리 생성
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            // 초기 데이터 처리
            self?.processHeartRateSamples(samples)
        }

        // Step 3: 업데이트 핸들러 설정 (새로운 심박수 데이터 수신)
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        // Step 4: 쿼리 실행
        healthStore.execute(query)
        heartRateQuery = query

        print("💓 심박수 스트리밍 시작")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 심박수 샘플 처리 및 센서 데이터 업데이트
    // ═══════════════════════════════════════
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample],
              let latestSample = heartRateSamples.last else {
            return
        }

        // 심박수 값 추출 (bpm)
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let heartRate = latestSample.quantity.doubleValue(for: heartRateUnit)

        DispatchQueue.main.async { [weak self] in
            self?.currentHeartRate = heartRate

            // Step: 심박수 업데이트 시 최신 모션 데이터와 결합하여 즉시 센서 데이터 갱신
            if let motion = self?.latestDeviceMotion {
                self?.createAndPublishSensorData(motion: motion)
            }
//            print("💓 심박수 업데이트: \(heartRate) bpm") 👈 디버깅이 많아서 주석처리
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 심박수 스트리밍 중지
    // ═══════════════════════════════════════
    private func stopHeartRateStreaming() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
            print("💓 심박수 스트리밍 중지")
        }
    }

    // MARK: - Motion Monitoring

    // ═══════════════════════════════════════
    // PURPOSE: CoreMotion을 사용한 가속도계/자이로스코프 데이터 수집 (이벤트 기반 실시간 업데이트)
    // NOTE: watchOS에서는 DeviceMotion을 사용해야 자이로스코프 데이터 접근 가능
    // ═══════════════════════════════════════
    private func startMotionUpdates() {
        // Step 1: 디바이스 모션 사용 가능 여부 확인
        print("🔍 디바이스 모션 사용 가능 여부: \(motionManager.isDeviceMotionAvailable)")

        guard motionManager.isDeviceMotionAvailable else {
            print("❌ 디바이스 모션을 사용할 수 없습니다")
            DispatchQueue.main.async {
                self.errorMessage = "모션 센서를 사용할 수 없습니다"
            }
            return
        }

        // Step 2: 업데이트 주기 설정 (0.1초마다 업데이트)
        motionManager.deviceMotionUpdateInterval = 0.1

        // Step 3: 디바이스 모션 업데이트 시작 - 이벤트 발생 즉시 센서 데이터 생성 및 전송
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            if let error = error {
                print("❌ 디바이스 모션 오류: \(error)")
                return
            }

            if let motion = motion {
                self?.latestDeviceMotion = motion
                // Step: 모션 데이터 수신 즉시 센서 데이터 생성 및 게시
                self?.createAndPublishSensorData(motion: motion)
            }
        }

        print("✅ 디바이스 모션 시작 (가속도계 + 자이로스코프, 이벤트 기반)")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 모션 센서 업데이트 중지
    // ═══════════════════════════════════════
    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        latestDeviceMotion = nil
        print("📱 디바이스 모션 중지")
    }

    // MARK: - Sensor Data Update

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터 생성 및 게시 (이벤트 기반 즉시 업데이트)
    // ═══════════════════════════════════════
    private func createAndPublishSensorData(motion: CMDeviceMotion) {
        // Step 1: 가속도계 데이터 추출 (userAcceleration: 중력 제외한 가속도)
        let accelX = motion.userAcceleration.x
        let accelY = motion.userAcceleration.y
        let accelZ = motion.userAcceleration.z

        // Step 2: 자이로스코프 데이터 추출 (rotationRate)
        let gyroX = motion.rotationRate.x
        let gyroY = motion.rotationRate.y
        let gyroZ = motion.rotationRate.z

        // Step 3: SensorData 객체 생성
        let sensorData = SensorData(
            heartRate: currentHeartRate,
            accelerometerX: accelX,
            accelerometerY: accelY,
            accelerometerZ: accelZ,
            gyroscopeX: gyroX,
            gyroscopeY: gyroY,
            gyroscopeZ: gyroZ,
            timestamp: Date()
        )

        // Step 4: 센서 데이터 즉시 게시 (이미 메인 스레드에서 실행 중)
        currentSensorData = sensorData
    }

    // MARK: - Permission Handling

    // ═══════════════════════════════════════
    // PURPOSE: HealthKit 권한 요청
    // ═══════════════════════════════════════
    private func requestHealthKitAuthorization() async throws {
        // Step 1: HealthKit 사용 가능 여부 확인
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(
                domain: "WatchSensorManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit을 사용할 수 없습니다"]
            )
        }

        // Step 2: 심박수 타입 정의
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw NSError(
                domain: "WatchSensorManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "심박수 타입을 찾을 수 없습니다"]
            )
        }

        // Step 3: 읽기 권한 요청
        let typesToRead: Set<HKObjectType> = [heartRateType]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            print("✅ HealthKit 권한 승인")
        } catch {
            print("❌ HealthKit 권한 거부: \(error)")
            throw error
        }
    }
}
