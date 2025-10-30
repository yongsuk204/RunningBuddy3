import SwiftUI

// Purpose: 케이던스(분당 스텝 수) 표시 카드 UI 컴포넌트
struct CadenceCard: View {

    // MARK: - Properties

    // Purpose: 평균 케이던스 값 (SPM - Steps Per Minute)
    let cadence: Double

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // 러닝 아이콘
            Image(systemName: "figure.run")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            // 제목
            Text("평균 케이던스")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))

            // 케이던스 값
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", cadence))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("SPM")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }

            // 설명 텍스트
            Text("분당 스텝 수")
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
                        .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
}
