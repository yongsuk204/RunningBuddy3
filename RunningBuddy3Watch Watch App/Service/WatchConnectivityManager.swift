import Foundation
import WatchConnectivity
import Combine
import CoreLocation

// Purpose: Apple Watch에서 iPhone으로 센서 데이터 전송 및 명령 수신 (WatchConnectivity 사용)
// MARK: - 함수 목록
/*
 * Initialization
 * - activateSession(): WCSession 활성화
 *
 * Data Transmission
 * - sendSensorData(_:): 센서 데이터를 iPhone으로 전송
 * - sendLocation(_:): GPS 위치 데이터를 iPhone으로 전송 (거리 계산은 iPhone에서)
 *
 * WCSessionDelegate
 * - session(_:activationDidCompleteWith:error:): 세션 활성화 완료 처리
 * - session(_:didReceiveMessage:): iPhone으로부터 명령 수신
 * - sessionReachabilityDidChange(_:): iPhone 연결 상태 변경 처리
 */

// Purpose: iPhone으로부터 수신한 운동 제어 명령
enum ReceivedCommand: String {
    case start = "start"
    case stop = "stop"
}

class WatchConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties

    // Purpose: iPhone과의 연결 상태
    @Published var isReachable = false

    // Purpose: 세션 활성화 상태
    @Published var isSessionActivated = false

    // Purpose: 수신한 명령
    @Published var receivedCommand: ReceivedCommand?

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
        print("⌚️ WatchConnectivity 세션 활성화 시작")
    }

    // MARK: - Data Transmission

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터를 iPhone으로 전송
    // ═══════════════════════════════════════
    func sendSensorData(_ data: SensorData) {
        // Step 1: 세션 상태 확인
        guard let session = session,
              session.isReachable else {
            print("⚠️ iPhone에 연결되지 않았습니다")
            return
        }

        // Step 2: SensorData를 딕셔너리로 변환
        let message = data.toDictionary()

        // Step 3: iPhone으로 메시지 전송
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ 센서 데이터 전송 실패: \(error.localizedDescription)")
        }

        // 디버그 로그 (심박수만 표시) 👈 디버깅이 많아서 주석처리
//        if let heartRate = data.heartRate {
//            print("📤 센서 데이터 전송: 심박수 \(heartRate) bpm")
//        } else {
//            print("📤 센서 데이터 전송 (심박수 없음)")
//        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: GPS 위치 데이터를 iPhone으로 전송 (거리 계산은 iPhone에서)
    // PARAMETERS:
    //   - location: GPS 위치
    // NOTE: 5미터마다 전송 (WatchGPSManager의 distanceFilter 설정에 따름)
    // ═══════════════════════════════════════
    func sendLocation(_ location: CLLocation) {
        // Step 1: 세션 상태 확인
        guard let session = session,
              session.isReachable else {
            return
        }

        // Step 2: 위치 데이터 딕셔너리 생성
        let message: [String: Any] = [
            "type": "location",
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "altitude": location.altitude,
            "horizontalAccuracy": location.horizontalAccuracy,
            "verticalAccuracy": location.verticalAccuracy,
            "speed": location.speed,
            "course": location.course,
            "timestamp": location.timestamp.timeIntervalSince1970
        ]

        // Step 3: iPhone으로 메시지 전송
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ GPS 위치 전송 실패: \(error.localizedDescription)")
        }

        print("📍 GPS 위치 전송: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

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
            } else {
                print("✅ WCSession 활성화 완료: \(activationState.rawValue)")
                self.isSessionActivated = true
                self.isReachable = session.isReachable
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: iPhone으로부터 명령 수신
    // ═══════════════════════════════════════
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Step 1: 명령 타입 확인
        guard let commandString = message["command"] as? String,
              let command = ReceivedCommand(rawValue: commandString) else {
            print("⚠️ 알 수 없는 명령 수신")
            return
        }

        // Step 2: 메인 스레드에서 명령 게시
        DispatchQueue.main.async {
            self.receivedCommand = command
            print("📥 명령 수신: \(command.rawValue)")
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: iPhone 연결 상태 변경 처리
    // ═══════════════════════════════════════
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("📱 iPhone 연결 상태: \(session.isReachable ? "연결됨" : "연결 해제")")
        }
    }
}
