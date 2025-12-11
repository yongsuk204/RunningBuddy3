import Foundation
import CoreLocation
import Combine

// Purpose: 디바이스 나침반(heading) 방향 추적 관리
class HeadingManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = HeadingManager()

    // MARK: - Published Properties

    // Purpose: 현재 디바이스가 향하고 있는 방향 (북쪽 기준 각도, 0-360)
    @Published var currentHeading: CLLocationDirection = 0

    // Purpose: heading 업데이트 활성 상태
    @Published var isUpdating: Bool = false

    // MARK: - Private Properties

    // Purpose: 위치 관리자
    private let locationManager = CLLocationManager()

    // MARK: - Initialization

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.headingFilter = 5 // 5도 이상 변화 시에만 업데이트
    }

    // MARK: - Public Methods

    // Purpose: heading 업데이트 시작
    func startUpdatingHeading() {
        guard CLLocationManager.headingAvailable() else {
            return
        }

        locationManager.startUpdatingHeading()
        isUpdating = true
    }

    // Purpose: heading 업데이트 중지
    func stopUpdatingHeading() {
        locationManager.stopUpdatingHeading()
        isUpdating = false
    }
}

// MARK: - CLLocationManagerDelegate

extension HeadingManager: CLLocationManagerDelegate {

    // Purpose: heading 업데이트 수신
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Step 1: trueHeading 사용 (진북 기준, GPS 필요)
        // trueHeading이 유효하지 않으면 magneticHeading 사용 (자북 기준, 방어적 fallback)
        if newHeading.trueHeading >= 0 {
            currentHeading = newHeading.trueHeading
        } else {
            currentHeading = newHeading.magneticHeading
        }
    }

    // Purpose: heading 업데이트 실패 처리
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Heading 업데이트 실패: \(error.localizedDescription)")
    }
}
