import SwiftUI

// Purpose: 모달에서 사용할 공통 버튼 스타일 컴포넌트
struct ModalButton: View {

    // MARK: - Button Types

    enum ButtonType {
        case primary
        case secondary
        case text

        // Purpose: 버튼 배경 색상 (Material이 없을 때 또는 비활성화 시 사용)
        var backgroundColor: Color {
            switch self {
            case .primary:
                return Color.clear // Material은 별도 처리
            case .secondary:
                return Color.clear
            case .text:
                return Color.clear
            }
        }

        // Purpose: 버튼 배경 Material (활성화 상태일 때 우선 사용)
        var backgroundMaterial: Material? {
            switch self {
            case .primary:
                return .ultraThinMaterial // Glass UI 효과
            case .secondary, .text:
                return nil // Material 사용 안함
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .secondary:
                return .white
            case .text:
                return .white.opacity(0.9)
            }
        }

        var font: Font {
            switch self {
            case .primary:
                return .headline
            case .secondary:
                return .subheadline
            case .text:
                return .caption
            }
        }
    }

    // MARK: - Properties

    let title: String
    let type: ButtonType
    let isDisabled: Bool
    let action: () -> Void

    // MARK: - Initializer

    init(
        title: String,
        type: ButtonType = .primary,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.type = type
        self.isDisabled = isDisabled
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .disabled(isDisabled)
    }

    // MARK: - Button Content

    // Purpose: 버튼 타입에 따라 적절한 컨텐츠를 반환하는 중앙 라우터
    @ViewBuilder
    private var buttonContent: some View {
        switch type {
        case .primary:
            primaryButtonContent
        case .secondary:
            secondaryButtonContent
        case .text:
            textButtonContent
        }
    }

    // MARK: - Primary Button

    // Purpose: Glass UI 효과를 가진 주요 버튼 (Material과 Color를 조건별로 처리)
    private var primaryButtonContent: some View {
        Text(title)
            .font(type.font)
            .foregroundColor(isDisabled ? type.foregroundColor.opacity(0.5) : type.foregroundColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                Group {
                    // Step 1: Material vs Color 선택 로직
                    // 활성화 상태 + Material이 있으면 Material 사용 (Glass UI)
                    if let material = type.backgroundMaterial, !isDisabled {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(material) // .ultraThinMaterial로 Glass 효과
                    } else {
                        // 비활성화 상태거나 Material이 없으면 Color 사용
                        RoundedRectangle(cornerRadius: 12)
                            .fill(type.backgroundColor.opacity(isDisabled ? 0.3 : 1.0))
                    }
                }
            )
    }

    // MARK: - Secondary Button

    // Purpose: 반투명 배경의 보조 버튼
    private var secondaryButtonContent: some View {
        Text(title)
            .font(type.font)
            .foregroundColor(isDisabled ? type.foregroundColor.opacity(0.5) : type.foregroundColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(isDisabled ? 0.3 : 0.5))
            )
    }

    // MARK: - Text Button

    // Purpose: 배경과 테두리 없는 순수 텍스트 버튼 (링크 스타일)
    private var textButtonContent: some View {
        Text(title)
            .font(type.font)
            .foregroundColor(isDisabled ? type.foregroundColor.opacity(0.5) : type.foregroundColor)
    }
}

// MARK: - Navigation Buttons

// Purpose: 이전/다음 버튼을 쉽게 만들 수 있는 헬퍼 구조체
// 모달에서 공통으로 사용되는 네비게이션 패턴을 재사용 가능한 컴포넌트로 추상화
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

    // Purpose: 조건에 따라 이전/다음 버튼을 표시하는 레이아웃
    var body: some View {
        HStack(spacing: 12) {
            // Step 1: 이전 버튼 (Secondary 스타일, 테두리만)
            if canGoBack {
                ModalButton(
                    title: "이전",
                    type: .secondary,  // Ghost button 스타일
                    action: onBack
                )
            }

            // Step 2: 다음 버튼 (Primary 스타일, Glass UI)
            if canGoNext {
                ModalButton(
                    title: nextButtonTitle,
                    type: .primary,    // Material background 스타일
                    isDisabled: isNextDisabled,
                    action: onNext
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

// Purpose: 모든 버튼 타입과 NavigationButtons의 시각적 테스트를 위한 프리뷰
struct ModalButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // 실제 앱과 동일한 배경 그라데이션
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // 각 버튼 타입별 샘플
                ModalButton(title: "Primary Button", type: .primary) {}      // Glass UI 효과
                ModalButton(title: "Secondary Button", type: .secondary) {}  // Ghost 스타일
                ModalButton(title: "Text Button", type: .text) {}            // 링크 스타일
                ModalButton(title: "Disabled Button", type: .primary, isDisabled: true) {} // 비활성화 상태

                // NavigationButtons 조합 테스트
                NavigationButtons(
                    nextButtonTitle: "완료",
                    onBack: {},
                    onNext: {}
                )
            }
            .padding()
        }
    }
}