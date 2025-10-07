import SwiftUI

// Purpose: 심박수 표시 카드 UI 컴포넌트
struct HeartRateCard: View {

    // MARK: - Properties

    // Purpose: 심박수 값 (bpm)
    let heartRate: Double

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // 하트 아이콘
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)

            // 제목
            Text("심박수")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))

            // 심박수 값
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", heartRate))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("bpm")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color.red.opacity(0.3), radius: 10, x: 0, y: 5)
        )
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

        HeartRateCard(heartRate: 78)
            .padding()
    }
}
