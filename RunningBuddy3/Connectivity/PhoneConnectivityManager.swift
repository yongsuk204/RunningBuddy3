import Foundation
import WatchConnectivity
import Combine
import CoreLocation

// Purpose: iPhone에서 Apple Watch로부터 센서 데이터 수신 및 명령 전송 (WatchConnectivity 사용)
// MARK: - 함수 목록
/*
 * Initialization
 * - activateSession(): WCSession 활성화
 *
 * Command Transmission
 * - sendCommand(_:): Watch로 운동 제어 명령 전송
 *
 * WCSessionDelegate
 * - session(_:activationDidCompleteWith:error:): 세션 활성화 완료 처리
 * - session(_:didReceiveMessage:): Watch로부터 센서 데이터 수신
 * - sessionDidBecomeInactive(_:): 세션 비활성화 처리
 * - sessionDidDeactivate(_:): 세션 비활성화 완료 처리
 */

// Purpose: 워치 운동 제어 명령 타입
enum WorkoutCommand: String {
    case start = "start"
    case stop = "stop"
}

class PhoneConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = PhoneConnectivityManager()

    // MARK: - Published Properties

    // Purpose: Watch로부터 수신한 최신 센서 데이터
    @Published var receivedSensorData: SensorData?

    // Purpose: Watch로부터 수신한 GPS 위치 (DistanceCalculator로 전달)
    @Published var receivedLocation: CLLocation?

    // Purpose: Watch와의 연결 상태
    @Published var isWatchReachable = false

    // Purpose: 세션 활성화 상태
    @Published var isSessionActivated = false

    // MARK: - Private Properties

    // Purpose: WatchConnectivity 세션
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    // MARK: - Initialization

    private override init() {
        super.init()
        setupSession()
    }

    // MARK: - Session Setup

    // ═══════════════════════════════════════
    // PURPOSE: WCSession 초기화 및 활성화
    // ═══════════════════════════════════════
    private func setupSession() {
        guard let session = session else {
            print("❌ WatchConnectivity가 지원되지 않습니다")
            return
        }

        session.delegate = self
        session.activate()
        print("📱 WatchConnectivity 세션 활성화 시작")
    }

    // MARK: - Reconnection

    // ═══════════════════════════════════════
    // PURPOSE: WCSession 수동 재연결 시도
    // ═══════════════════════════════════════
    func reconnect() {
        guard let session = session else {
            print("❌ WatchConnectivity가 지원되지 않습니다")
            return
        }

        // Step 1: 현재 상태 확인
        print("🔄 재연결 시도 중...")
        print("  - 활성화 상태: \(session.activationState.rawValue)")
        print("  - Paired: \(session.isPaired)")
        print("  - Installed: \(session.isWatchAppInstalled)")
        print("  - Reachable: \(session.isReachable)")

        // Step 2: 세션 재활성화
        if session.activationState != .activated {
            session.activate()
        }

        // Step 3: 연결 상태 업데이트
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    // MARK: - Command Transmission

    // ═══════════════════════════════════════
    // PURPOSE: Watch로 운동 제어 명령 전송
    // ═══════════════════════════════════════
    func sendCommand(_ command: WorkoutCommand) {
        // Step 1: 세션 상태 확인
        guard let session = session,
              session.isReachable else {
            print("⚠️ Apple Watch에 연결되지 않았습니다")
            return
        }

        // Step 2: 명령을 딕셔너리로 변환
        let message = ["command": command.rawValue]

        // Step 3: Watch로 메시지 전송
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ 명령 전송 실패: \(error.localizedDescription)")
        }

        print("📤 명령 전송: \(command.rawValue)")
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {

    // ═══════════════════════════════════════
    // PURPOSE: 세션 활성화 완료 처리
    // ═══════════════════════════════════════
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ WCSession 활성화 실패: \(error.localizedDescription)")
                self.isSessionActivated = false
                self.isWatchReachable = false
            } else {
                print("✅ WCSession 활성화 완료: \(activationState.rawValue)")
                self.isSessionActivated = true
                self.isWatchReachable = session.isReachable
                print("⌚️ Watch 초기 연결 상태: \(session.isReachable ? "연결됨" : "연결 해제")")
                print("⌚️ Watch paired: \(session.isPaired), installed: \(session.isWatchAppInstalled)")
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: Watch로부터 메시지 수신 (센서 데이터 또는 GPS 위치)
    // ═══════════════════════════════════════
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Step 1: GPS 위치 메시지 처리
        if let gpsData = GPSData.fromDictionary(message) {
            let location = gpsData.toCLLocation()

            // 👈 워치로부터 받은 위치정보를 업데이트함
            DispatchQueue.main.async { [weak self] in
                self?.receivedLocation = location

                // DistanceCalculator.shared로 GPS 위치 전달 (실시간측정 + 캘리브레이션 공통)
                DistanceCalculator.shared.addLocation(location)
            }

            print("📍 GPS 위치 수신: (\(String(format: "%.6f", gpsData.latitude)), \(String(format: "%.6f", gpsData.longitude)))")
            return
        }

        // Step 2: 센서 데이터 메시지 처리 👈 워치로부터 받은 센서데이터를 업데이트함
        guard let sensorData = SensorData.fromDictionary(message) else {
            return
        }

        // Step 3: 메인 스레드는 최소한만 사용 - Published 프로퍼티 업데이트만
        DispatchQueue.main.async { [weak self] in
            self?.receivedSensorData = sensorData
        }

        // Step 4: 캘리브레이션 측정 중이면 센서 데이터 수집
        CalibrationSession.shared.addSensorData(sensorData)

        // 디버그 로그 (주석처리 - 너무 빈번한 출력 방지)
//        if let heartRate = sensorData.heartRate {
//            print("📥 센서 데이터 수신: 심박수 \(heartRate) bpm")
//        } else {
//            print("📥 센서 데이터 수신 (심박수 없음)")
//        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 세션 비활성화 처리 (iOS 전용)
    // ═══════════════════════════════════════
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ WCSession 비활성화됨")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 세션 재활성화 처리 (iOS 전용)
    // ═══════════════════════════════════════
    func sessionDidDeactivate(_ session: WCSession) {
        print("🔄 WCSession 재활성화 시도")
        // 세션 재활성화
        session.activate()
    }

    // ═══════════════════════════════════════
    // PURPOSE: Watch 연결 상태 변경 처리
    // ═══════════════════════════════════════
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("⌚️ Watch 연결 상태: \(session.isReachable ? "연결됨" : "연결 해제")")
        }
    }
}
