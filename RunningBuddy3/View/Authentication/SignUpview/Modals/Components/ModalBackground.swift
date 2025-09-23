import SwiftUI

// Purpose: 모달들에서 사용할 공통 배경 스타일 컴포넌트
struct ModalBackground: View {

    // MARK: - Properties

    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: CGSize

    // MARK: - Initializer

    init(
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 20,
        shadowOffset: CGSize = CGSize(width: 0, height: 10)
    ) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
    }

    // MARK: - Body

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .shadow(
                color: .black.opacity(0.2),
                radius: shadowRadius,
                x: shadowOffset.width,
                y: shadowOffset.height
            )
    }
}

// MARK: - Field Background

// Purpose: 입력 필드에서 사용할 공통 배경 스타일
struct FieldBackground: View {

    // MARK: - Properties

    let cornerRadius: CGFloat
    let strokeColor: Color
    let strokeWidth: CGFloat

    // MARK: - Initializer

    init(
        cornerRadius: CGFloat = 12,
        strokeColor: Color = Color.white.opacity(0.2),
        strokeWidth: CGFloat = 1
    ) {
        self.cornerRadius = cornerRadius
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
    }

    // MARK: - Body

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
    }
}

// MARK: - Preview

struct ModalBackground_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Modal Background 예시
                VStack {
                    Text("Modal Background")
                        .foregroundColor(.white)
                        .padding()
                }
                .frame(width: 300, height: 100)
                .background(ModalBackground())

                // Field Background 예시
                HStack {
                    Text("Field Background")
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(FieldBackground())
                .frame(width: 300)
            }
            .padding()
        }
    }
}