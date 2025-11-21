import SwiftUI

// Purpose: 공통 유효성 검증 피드백 아이콘 컴포넌트
struct ValidationFeedbackIcon: View {

    // MARK: - Types

    enum ValidationStatus: Equatable {
        case none
        case checking
        case valid
        case invalid
    }

    // MARK: - Properties

    let status: ValidationStatus
    let size: CGFloat

    // MARK: - Initialization

    init(status: ValidationStatus, size: CGFloat = 20) {
        self.status = status
        self.size = size
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch status {
            case .none:
                EmptyView()

            case .checking:
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(DesignSystem.Colors.info)

            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.success)

            case .invalid:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.error)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 15) {
        ValidationFeedbackIcon(status: .none)
        ValidationFeedbackIcon(status: .checking)
        ValidationFeedbackIcon(status: .valid)
        ValidationFeedbackIcon(status: .invalid)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}