import SwiftUI

// Purpose: Apple Watch 운동 측정 화면 - 센서 데이터 실시간 표시 및 iPhone 전송
struct WatchWorkoutView: View {

    // MARK: - Properties

    @StateObject private var sensorManager = WatchSensorManager()
    @StateObject private var connectivity = WatchConnectivityManager.shared

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 헤더
                headerSection

                // 센서 데이터 표시
                if sensorManager.isMonitoring {
                    sensorDataSection
                } else {
                    placeholderSection
                }

                // 시작/중지 버튼
                controlButton
                    .padding(.top, 8)
            }
            .padding()
        }
        .onChange(of: sensorManager.currentSensorData) { oldValue, newValue in
            // 센서 데이터가 업데이트되면 iPhone으로 전송
            if let data = newValue {
                connectivity.sendSensorData(data)
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
            if let sensorData = sensorManager.currentSensorData {
                HStack(spacing: 16) {
                    // 가속도계
                    VStack(spacing: 2) {
                        Image(systemName: "move.3d")
                            .font(.caption)
                            .foregroundColor(.blue)

                        Text("\(sensorData.accelerometerMagnitude, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.white)

                        Text("m/s²")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }

                    // 자이로스코프
                    VStack(spacing: 2) {
                        Image(systemName: "gyroscope")
                            .font(.caption)
                            .foregroundColor(.purple)

                        Text("\(sensorData.gyroscopeMagnitude, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.white)

                        Text("rad/s")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    // MARK: - Placeholder Section

    private var placeholderSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("준비됨")
                .font(.headline)
                .foregroundColor(.white)

            Text("시작 버튼을 눌러주세요")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Control Button

    private var controlButton: some View {
        Button {
            if sensorManager.isMonitoring {
                sensorManager.stopMonitoring()
            } else {
                Task {
                    await sensorManager.startMonitoring()
                }
            }
        } label: {
            HStack {
                Image(systemName: sensorManager.isMonitoring ? "stop.fill" : "play.fill")
                Text(sensorManager.isMonitoring ? "중지" : "시작")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(sensorManager.isMonitoring ? Color.red : Color.green)
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}
