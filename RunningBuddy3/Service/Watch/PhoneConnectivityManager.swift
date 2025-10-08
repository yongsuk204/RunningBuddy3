import Foundation
import WatchConnectivity
import Combine

// Purpose: iPhone에서 Apple Watch로부터 센서 데이터 수신 (WatchConnectivity 사용)
// MARK: - 함수 목록
/*
 * Initialization
 * - activateSession(): WCSession 활성화
 *
 * WCSessionDelegate
 * - session(_:activationDidCompleteWith:error:): 세션 활성화 완료 처리
 * - session(_:didReceiveMessage:): Watch로부터 센서 데이터 수신
 * - sessionDidBecomeInactive(_:): 세션 비활성화 처리
 * - sessionDidDeactivate(_:): 세션 비활성화 완료 처리
 */

class PhoneConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = PhoneConnectivityManager()

    // MARK: - Published Properties

    // Purpose: Watch로부터 수신한 최신 센서 데이터
    @Published var receivedSensorData: SensorData?

    // Purpose: Watch와의 연결 상태
    @Published var isWatchReachable = false

    // Purpose: 세션 활성화 상태
    @Published var isSessionActivated = false

    // Purpose: 마지막 업데이트 시간
    @Published var lastUpdateTime: Date?

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
            } else {
                print("✅ WCSession 활성화 완료: \(activationState.rawValue)")
                self.isSessionActivated = true
                self.isWatchReachable = session.isReachable
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: Watch로부터 센서 데이터 수신
    // ═══════════════════════════════════════
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Step 1: 딕셔너리를 SensorData로 변환
        guard let sensorData = SensorData.fromDictionary(message) else {
            print("❌ 센서 데이터 변환 실패")
            return
        }

        // Step 2: 메인 스레드에서 데이터 업데이트
        DispatchQueue.main.async {
            self.receivedSensorData = sensorData
            self.lastUpdateTime = Date()

            // 디버그 로그
            if let heartRate = sensorData.heartRate {
                print("📥 센서 데이터 수신: 심박수 \(heartRate) bpm")
            } else {
                print("📥 센서 데이터 수신 (심박수 없음)")
            }
        }
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
