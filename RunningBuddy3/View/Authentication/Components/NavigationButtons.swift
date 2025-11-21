import SwiftUI

// Purpose: 모달 네비게이션 버튼 컴포넌트 (DesignSystem 기반)
// 이전/다음 버튼을 쉽게 만들 수 있는 헬퍼 구조체
struct NavigationButtons: View {

    // MARK: - Properties

    let canGoBack: Bool        // 이전 버튼 표시 여부
    let canGoNext: Bool        // 다음 버튼 표시 여부
    let nextButtonTitle: String // 다음 버튼 텍스트 (예: "다음", "완료", "회원가입")
    let isNextDisabled: Bool   // 다음 버튼 비활성화 상태
    let onBack: () -> Void     // 이전 버튼 액션
    let onNext: () -> Void     // 다음 버튼 액션

    // MARK: - Initializer

    init(
        canGoBack: Bool = true,
        canGoNext: Bool = true,
        nextButtonTitle: String = "다음",
        isNextDisabled: Bool = false,
        onBack: @escaping () -> Void = {},
        onNext: @escaping () -> Void = {}
    ) {
        self.canGoBack = canGoBack
        self.canGoNext = canGoNext
        self.nextButtonTitle = nextButtonTitle
        self.isNextDisabled = isNextDisabled
        self.onBack = onBack
        self.onNext = onNext
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // 이전 버튼 (Secondary 스타일)
            if canGoBack {
                Button(action: onBack) {
                    Text("이전")
                        .frame(maxWidth: .infinity)
                }
                .modalSecondaryButtonStyle()
                .contentShape(Rectangle())
            }

            // 다음 버튼 (Primary 스타일)
            if canGoNext {
                Button(action: onNext) {
                    Text(nextButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .modalPrimaryButtonStyle(isDisabled: isNextDisabled)
                .contentShape(Rectangle())
                .disabled(isNextDisabled)
            }
        }
        .padding(.horizontal)
    }
}
