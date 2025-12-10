import Foundation
import CoreLocation
import Combine

// Purpose: Apple Watch에서 GPS 위치 데이터 수집 (거리 계산은 DistanceCalculator에서 수행)
// MARK: - 함수 목록
/*
 * Location Tracking
 * - startTracking(): GPS 추적 시작 (위치 업데이트 시작)
 * - stopTracking(): GPS 추적 중지 및 리소스 정리
 *
 * Location Updates
 * - locationManager(_:didUpdateLocations:): 새로운 위치 수신 시 업데이트 및 전송
 *
 * GPS 설정:
 * - desiredAccuracy: kCLLocationAccuracyBest (최고 정확도)
 * - distanceFilter: 3.0 (3미터마다 업데이트)
 * - activityType: .fitness (운동 모드)
 */

class WatchGPSManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Singleton

    static let shared = WatchGPSManager()

    // MARK: - Published Properties

    // Purpose: 최신 GPS 위치 (DistanceCalculator에서 감지하여 거리 계산)
    @Published var currentLocation: CLLocation?

    // Purpose: GPS 추적 상태
    @Published var isTracking: Bool = false

    // MARK: - Private Properties

    // Purpose: 위치 관리자 (GPS 데이터 수신)
    private let locationManager = CLLocationManager()

    // Purpose: GPS 추적 시작 요청 플래그 (권한 허용 후 자동 시작용)
    private var shouldStartTracking = false

    // MARK: - Initialization

    private override init() {
        super.init()
        setupLocationManager()
    }

    // ═══════════════════════════════════════
    // PURPOSE: 위치 관리자 초기 설정
    // ═══════════════════════════════════════
    private func setupLocationManager() {
        // Step 1: Delegate 설정
        locationManager.delegate = self

        // Step 2: 정확도 설정 (최고 정확도)
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        // Step 3: 거리 필터 (3미터마다 업데이트)
        locationManager.distanceFilter = 3.0

        // Step 4: 활동 타입 (운동 모드)
        locationManager.activityType = .fitness

        // Step 5: 백그라운드 위치 업데이트 허용
        locationManager.allowsBackgroundLocationUpdates = true

        // Step 6: 권한 요청 (Always 권한 - 백그라운드 GPS 추적용)
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Public Methods

    // ═══════════════════════════════════════
    // PURPOSE: GPS 추적 시작
    // FUNCTIONALITY:
    //   - 권한 상태 확인
    //   - 권한이 없으면 요청 (팝업 표시)
    //   - 권한이 있으면 즉시 추적 시작
    // ═══════════════════════════════════════
    func startTracking() {
        // Step 1: 권한 상태 확인
        let status = locationManager.authorizationStatus

        // Step 2: 권한 상태에 따른 처리
        switch status {
        case .notDetermined:
            // 권한 요청 전 → 권한 요청 팝업 표시
            shouldStartTracking = true
            locationManager.requestAlwaysAuthorization()
            // 권한 허용 시 locationManagerDidChangeAuthorization에서 자동 시작됨

        case .denied, .restricted:
            // 권한 거부 → 사용자에게 안내
            print("❌ GPS 권한이 거부되었습니다. Watch 설정에서 위치 권한을 허용해주세요.")
            shouldStartTracking = false

        case .authorizedAlways, .authorizedWhenInUse:
            // 권한 허용됨 → 즉시 추적 시작
            startLocationUpdates()

        @unknown default:
            break
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 실제 GPS 위치 업데이트 시작
    // ═══════════════════════════════════════
    private func startLocationUpdates() {
        locationManager.startUpdatingLocation()

        DispatchQueue.main.async {
            self.isTracking = true
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 권한 상태를 문자열로 변환 (디버깅용)
    // ═══════════════════════════════════════
    private func authorizationStatusString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined (권한 요청 전)"
        case .restricted: return "restricted (제한됨)"
        case .denied: return "denied (거부됨)"
        case .authorizedAlways: return "authorizedAlways (항상 허용)"
        case .authorizedWhenInUse: return "authorizedWhenInUse (사용 중 허용)"
        @unknown default: return "unknown"
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: GPS 추적 중지
    // ═══════════════════════════════════════
    func stopTracking() {
        // Step 1: 위치 업데이트 중지
        locationManager.stopUpdatingLocation()

        // Step 2: 추적 상태 업데이트
        DispatchQueue.main.async {
            self.isTracking = false
        }
    }

    // MARK: - CLLocationManagerDelegate

    // ═══════════════════════════════════════
    // PURPOSE: 새로운 위치 수신 시 업데이트 및 전송
    // PARAMETERS:
    //   - locations: 새로운 위치 배열 (최신 위치는 마지막 요소)
    // FUNCTIONALITY:
    //   - 최신 위치를 @Published 속성으로 업데이트
    //   - 거리 계산은 DistanceCalculator에서 수행
    // ═══════════════════════════════════════
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Step 1: 최신 위치 가져오기
        guard let newLocation = locations.last else { return }

        // Step 2: 위치 업데이트 (DistanceCalculator 및 WatchWorkoutView에서 감지)
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = newLocation
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 위치 업데이트 실패 처리
    // ═══════════════════════════════════════
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ GPS 오류: \(error.localizedDescription)")
    }

    // ═══════════════════════════════════════
    // PURPOSE: GPS 권한 상태 변경 처리
    // FUNCTIONALITY:
    //   - 사용자가 권한 팝업에서 허용/거부 선택 시 호출됨
    //   - 권한 허용 시 자동으로 GPS 추적 시작
    // ═══════════════════════════════════════
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        // 권한이 허용되고 추적 시작이 요청된 상태면 자동 시작
        if shouldStartTracking {
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                shouldStartTracking = false
                startLocationUpdates()

            case .denied, .restricted:
                print("❌ GPS 권한 거부됨")
                shouldStartTracking = false

            default:
                break
            }
        }
    }
}
