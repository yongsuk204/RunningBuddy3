import Foundation
import WatchConnectivity
import Combine

// Purpose: Apple Watch에서 iPhone으로 센서 데이터 전송 (WatchConnectivity 사용)
// MARK: - 함수 목록
/*
 * Initialization
 * - activateSession(): WCSession 활성화
 *
 * Data Transmission
 * - sendSensorData(_:): 센서 데이터를 iPhone으로 전송
 *
 * WCSessionDelegate
 * - session(_:activationDidCompleteWith:error:): 세션 활성화 완료 처리
 * - sessionReachabilityDidChange(_:): iPhone 연결 상태 변경 처리
 */

class WatchConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties

    // Purpose: iPhone과의 연결 상태
    @Published var isReachable = false

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
    // PURPOSE: iPhone 연결 상태 변경 처리
    // ═══════════════════════════════════════
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("📱 iPhone 연결 상태: \(session.isReachable ? "연결됨" : "연결 해제")")
        }
    }
}
