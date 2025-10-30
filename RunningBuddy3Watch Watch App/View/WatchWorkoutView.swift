import SwiftUI

// Purpose: Apple Watch 운동 측정 화면 - 센서 데이터 실시간 표시 및 iPhone 전송
struct WatchWorkoutView: View {

    // MARK: - Properties

    @StateObject private var sensorManager = WatchSensorManager()
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @StateObject private var gpsManager = WatchGPSManager.shared

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 헤더
                headerSection

                // 센서 데이터 표시
                sensorDataSection
            }
            .padding()
        }
        .onChange(of: sensorManager.currentSensorData) { oldValue, newValue in
            // 센서 데이터가 업데이트되면 iPhone으로 전송
            if let data = newValue {
                connectivity.sendSensorData(data)
            }
        }
        .onChange(of: gpsManager.currentLocation?.timestamp) { oldValue, newValue in
            // GPS 위치가 업데이트되면 iPhone으로 전송 (거리 계산은 iPhone에서)
            if let location = gpsManager.currentLocation {
                connectivity.sendLocation(location)
            }
        }
        .onChange(of: connectivity.receivedCommand) { oldValue, newValue in
            // iPhone으로부터 명령 수신 시 처리
            guard let command = newValue else { return }

            Task {
                switch command {
                case .start:
                    await sensorManager.startMonitoring()
                    gpsManager.startTracking() // GPS 추적 시작
                case .stop:
                    sensorManager.stopMonitoring()
                    gpsManager.stopTracking() // GPS 추적 중지
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("Running Buddy")
                .font(.headline)
                .foregroundColor(.white)

            // 연결 상태 표시
            HStack(spacing: 4) {
                Circle()
                    .fill(connectivity.isReachable ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)

                Text(connectivity.isReachable ? "iPhone 연결됨" : "iPhone 연결 안 됨")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Sensor Data Section

    private var sensorDataSection: some View {
        VStack(spacing: 12) {
            // 심박수
            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundColor(.red)

                if let heartRate = sensorManager.currentHeartRate {
                    Text("\(Int(heartRate))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("--")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)

                    Text("측정 중...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // 센서 상태
            HStack(spacing: 16) {
                // 가속도계 X
                VStack(spacing: 2) {
                    Image(systemName: "move.3d")
                        .font(.caption)
                        .foregroundColor(.blue)

                    if let sensorData = sensorManager.currentSensorData {
                        Text("X: \(sensorData.accelerometerX, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.white)
                    } else {
                        Text("X: --")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Text("g")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }

                // 자이로스코프 X
                VStack(spacing: 2) {
                    Image(systemName: "gyroscope")
                        .font(.caption)
                        .foregroundColor(.purple)

                    if let sensorData = sensorManager.currentSensorData {
                        Text("X: \(sensorData.gyroscopeX, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.white)
                    } else {
                        Text("X: --")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Text("rad/s")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
            }

            // GPS 위치
            VStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.green)

                if let location = gpsManager.currentLocation {
                    VStack(spacing: 2) {
                        Text("위도: \(location.coordinate.latitude, specifier: "%.6f")")
                            .font(.caption2)
                            .foregroundColor(.white)

                        Text("경도: \(location.coordinate.longitude, specifier: "%.6f")")
                            .font(.caption2)
                            .foregroundColor(.white)

                        Text("정확도: \(location.horizontalAccuracy, specifier: "%.1f")m")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(spacing: 2) {
                        Text("위도: --")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Text("경도: --")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Text("GPS 대기 중...")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

}
