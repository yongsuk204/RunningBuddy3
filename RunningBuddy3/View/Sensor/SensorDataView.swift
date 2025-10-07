import SwiftUI

// Purpose: iPhone에서 Apple Watch 센서 데이터 실시간 표시 화면
struct SensorDataView: View {

    // MARK: - Properties

    @StateObject private var connectivityManager = PhoneConnectivityManager.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3), Color.teal.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 상태 헤더
                    statusHeader

                    if let sensorData = connectivityManager.receivedSensorData {
                        // 센서 데이터 표시
                        sensorDataContent(sensorData)
                    } else {
                        // 플레이스홀더
                        placeholderContent
                    }
                }
                .padding()
            }
        }
        .navigationTitle("실시간 센서")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 12) {
            // Apple Watch 연결 상태
            HStack(spacing: 8) {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundColor(connectivityManager.isWatchReachable ? .green : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(connectivityManager.isWatchReachable ? "Apple Watch 연결됨" : "Apple Watch 연결 안 됨")
                        .font(.headline)
                        .foregroundColor(.white)

                    if let lastUpdate = connectivityManager.lastUpdateTime {
                        Text("마지막 업데이트: \(lastUpdate, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                Circle()
                    .fill(connectivityManager.isWatchReachable ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(connectivityManager.isWatchReachable ? Color.green.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 2)
                    )
            )

            // 안내 메시지
            if !connectivityManager.isWatchReachable {
                Text("Apple Watch에서 측정을 시작하세요")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Sensor Data Content

    private func sensorDataContent(_ sensorData: SensorData) -> some View {
        VStack(spacing: 24) {
            // 심박수 카드
            if let heartRate = sensorData.heartRate {
                HeartRateCard(heartRate: heartRate)
            }

            // 가속도계 카드
            AccelerometerCard(data: sensorData)

            // 자이로스코프 카드
            GyroscopeCard(data: sensorData)

            // 타임스탬프
            Text("측정 시간: \(sensorData.timestamp, style: .time)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 8)
        }
    }

    // MARK: - Placeholder Content

    private var placeholderContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "applewatch.watchface")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: 8) {
                Text("센서 데이터 대기 중")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("Apple Watch에서 측정을 시작하면\n실시간으로 데이터가 표시됩니다")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    NavigationView {
        SensorDataView()
    }
}
