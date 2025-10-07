import SwiftUI

// Purpose: 자이로스코프 데이터 표시 카드 (X, Y, Z축 회전 속도 및 크기)
struct GyroscopeCard: View {

    // MARK: - Properties

    let data: SensorData?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HStack {
                Image(systemName: "gyroscope")
                    .font(.title2)
                    .foregroundColor(.purple)

                Text("자이로스코프")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                if data != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            if let data = data {
                // 크기 (Magnitude)
                VStack(spacing: 4) {
                    Text("회전 속도 크기")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Text(String(format: "%.3f rad/s", data.gyroscopeMagnitude))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 8)

                Divider()
                    .background(Color.white.opacity(0.3))

                // X, Y, Z 축
                HStack(spacing: 16) {
                    axisView(label: "X", value: data.gyroscopeX, color: .orange)
                    axisView(label: "Y", value: data.gyroscopeY, color: .pink)
                    axisView(label: "Z", value: data.gyroscopeZ, color: .purple)
                }
            } else {
                Text("데이터 없음")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Axis View

    private func axisView(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)

            Text(String(format: "%.2f", value))
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            Text("rad/s")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GyroscopeCard(
            data: SensorData(
                heartRate: 78,
                accelerometerX: 0.123,
                accelerometerY: -0.456,
                accelerometerZ: 0.789,
                gyroscopeX: 0.01,
                gyroscopeY: -0.02,
                gyroscopeZ: 0.03,
                timestamp: Date()
            )
        )
        .padding()
    }
}
