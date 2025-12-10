import Foundation
import HealthKit
import CoreMotion
import Combine

// Purpose: Apple Watch에서 센서 데이터 실시간 수집 (심박수, 가속도계, 자이로스코프) - 이벤트 기반 즉시 전송
// MARK: - 함수 목록
/*
 * Monitoring Control
 * - startMonitoring(): 센서 모니터링 시작 (Workout Session 기반)
 * - stopMonitoring(): 센서 모니터링 중지
 * - performSensorCleanup(): 센서 정리 작업 (백그라운드 안전 실행)
 *
 * Workout Session Management
 * - startWorkoutSession(): Workout 세션 시작 (Always-On Display 자동 활성화, 심박수 자동 수집)
 * - stopWorkoutSession(): Workout 세션 종료
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
 *
 * NOTE: 심박수는 Workout Builder의 delegate 메서드(workoutBuilder:didCollectDataOf:)에서 자동 수집 👈
 */

class WatchSensorManager: NSObject, ObservableObject {

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
    private static let motionManager: CMMotionManager = {
        let manager = CMMotionManager()
        return manager
    }()

    // Purpose: Workout 세션 (Always-On Display 유지용)
    private var workoutSession: HKWorkoutSession?

    // Purpose: Workout Builder (심박수 자동 수집용)
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // Purpose: 최근 디바이스 모션 데이터 (가속도계 + 자이로스코프 통합)
    private var latestDeviceMotion: CMDeviceMotion?

    // MARK: - Initialization

    override init() {
        super.init()
        // CMMotionManager는 shared instance 사용
    }

    // MARK: - Monitoring Control

    // ═══════════════════════════════════════
    // PURPOSE: 센서 모니터링 시작 (Workout Session 기반)
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
            return
        }

        // Step 2: Workout 세션 시작 (Always-On Display 활성화)
        do {
            try await startWorkoutSession()
        } catch {
            await MainActor.run {
                errorMessage = "Workout 세션 시작 실패: \(error.localizedDescription)"
            }
            print("❌ Workout 세션 시작 실패: \(error)")
            return
        }

        // Step 3: 모션 센서 시작 (이벤트 기반 실시간 업데이트)
        startMotionUpdates()

        // Step 4: 모니터링 상태 업데이트
        await MainActor.run {
            isMonitoring = true
        }
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
    }

    // ═══════════════════════════════════════
    // PURPOSE: 센서 정리 작업 (백그라운드에서 안전하게 실행)
    // ═══════════════════════════════════════
    @MainActor
    private func performSensorCleanup() async {
        stopMotionUpdates()
        stopWorkoutSession()
    }

    // MARK: - Workout Session Management

    // ═══════════════════════════════════════
    // PURPOSE: Workout 세션 시작 (Always-On Display 자동 활성화) 👈 workout세션 핵심부분
    // ═══════════════════════════════════════
    private func startWorkoutSession() async throws {
        // Step 1: Workout 설정 생성 (운동 타입: 러닝)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running     // 러닝 운동 타입
        configuration.locationType = .outdoor     // GPS 활성화 (거리 측정용)

        // Step 2: Workout 세션 생성
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        session.delegate = self
        workoutSession = session

        // Step 3: Workout Builder 생성 (심박수 자동 수집용)
        let builder = session.associatedWorkoutBuilder()
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        workoutBuilder = builder

        // Step 4: 세션 시작 (Always-On Display 활성화)
        session.startActivity(with: Date())

        // Step 5: Builder 시작 (심박수 수집 시작) 👈 이부분에 의해서 심박수 측정이 시작됨 델리게이트 감지
        try await builder.beginCollection(at: Date())
    }

    // ═══════════════════════════════════════
    // PURPOSE: Workout 세션 종료
    // ═══════════════════════════════════════
    private func stopWorkoutSession() {
        guard let session = workoutSession else { return }

        // Step 1: 세션 종료
        session.end()

        // Step 2: Builder 종료 👈 이부분에 의해서 심박수 측정이 정지됨 델리게이트 감지
        if let builder = workoutBuilder {
            builder.endCollection(withEnd: Date()) { success, error in
                if let error = error {
                    print("❌ Workout Builder 종료 오류: \(error)")
                }
            }
        }

        // Step 3: 참조 제거
        workoutSession = nil
        workoutBuilder = nil
    }

    // MARK: - Motion Monitoring

    // ═══════════════════════════════════════
    // PURPOSE: CoreMotion을 사용한 가속도계/자이로스코프 데이터 수집 (이벤트 기반 실시간 업데이트)
    // NOTE: watchOS에서는 DeviceMotion을 사용해야 자이로스코프 데이터 접근 가능
    // ═══════════════════════════════════════
    private func startMotionUpdates() {
        // Step 1: 디바이스 모션 사용 가능 여부 확인
        guard WatchSensorManager.motionManager.isDeviceMotionAvailable else {
            print("❌ 디바이스 모션을 사용할 수 없습니다")
            Task { @MainActor [weak self] in
                self?.errorMessage = "모션 센서를 사용할 수 없습니다"
            }
            return
        }

        // Step 2: 업데이트 주기 설정 (0.05초마다 업데이트 - 20Hz)
        WatchSensorManager.motionManager.deviceMotionUpdateInterval = 0.05

        // Step 3: 디바이스 모션 업데이트 시작 - 이벤트 발생 즉시 센서 데이터 생성 및 전송
        WatchSensorManager.motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
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
    }

    // ═══════════════════════════════════════
    // PURPOSE: 모션 센서 업데이트 중지
    // ═══════════════════════════════════════
    private func stopMotionUpdates() {
        WatchSensorManager.motionManager.stopDeviceMotionUpdates()
        latestDeviceMotion = nil
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

        // Step 3: SensorData 객체 생성 (GPS 거리는 별도 채널로 전송)
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

        // Step 2: 심박수 및 Workout 타입 정의
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw NSError(
                domain: "WatchSensorManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "심박수 타입을 찾을 수 없습니다"]
            )
        }

        // Step 3: 읽기/쓰기 권한 요청 (Workout 세션을 위해 쓰기 권한 필요)
        let typesToRead: Set<HKObjectType> = [heartRateType]
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),  // Workout 세션 생성 권한 (Always-On Display 활성화용)
            heartRateType  // 심박수 기록 권한
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        } catch {
            print("❌ HealthKit 권한 거부: \(error)")
            throw error
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchSensorManager: HKWorkoutSessionDelegate {

    // ═══════════════════════════════════════
    // PURPOSE: Workout 세션 상태 변경 처리
    // ═══════════════════════════════════════
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // Workout state changes are handled silently
    }

    // ═══════════════════════════════════════
    // PURPOSE: Workout 세션 실패 처리
    // ═══════════════════════════════════════
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.errorMessage = "Workout 세션 오류: \(error.localizedDescription)"
            print("❌ Workout 세션 오류: \(error)")
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchSensorManager: HKLiveWorkoutBuilderDelegate {

    // ═══════════════════════════════════════
    // PURPOSE: Workout Builder 데이터 수집 시작/중지 처리
    // ═══════════════════════════════════════
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Step 1: 심박수 타입 확인
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(heartRateType) else {
            return
        }

        // Step 2: 최신 심박수 통계 가져오기
        guard let statistics = workoutBuilder.statistics(for: heartRateType),
              let mostRecentSample = statistics.mostRecentQuantity() else {
            return
        }

        // Step 3: 심박수 값 추출 (bpm)
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let heartRate = mostRecentSample.doubleValue(for: heartRateUnit)

        // Step 4: 메인 스레드에서 업데이트
        // NOTE: 센서 데이터는 모션 업데이트(20Hz)에서 생성되므로 여기서는 심박수만 업데이트
        //       다음 모션 업데이트 시 최신 심박수가 자동으로 포함됨
        Task { @MainActor [weak self] in
            self?.currentHeartRate = heartRate
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: Workout Builder 이벤트 처리 (필요 시 구현)
    // ═══════════════════════════════════════
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // 필요 시 구현
    }
}
