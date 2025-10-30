import SwiftUI

// Purpose: 이동 거리 표시 카드 UI 컴포넌트
struct DistanceCard: View {

    // MARK: - Properties

    // Purpose: 이동 거리 값 (미터 단위)
    let distance: Double

    // MARK: - Computed Properties

    // Purpose: 거리를 킬로미터로 변환
    private var distanceInKm: Double {
        return distance / 1000.0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // 위치 아이콘
            Image(systemName: "location.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            // 제목
            Text("이동 거리")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))

            // 거리 값
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", distanceInKm))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("km")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }

            // 미터 단위 표시
            Text("\(String(format: "%.0f", distance))m")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
}
