import SwiftUI

// Purpose: 순차적 모달 기반 회원가입 메인 컨테이너 뷰
struct SignUpView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SignUpViewModel()

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.clear
                .appGradientBackground()

            mainContent
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Main Content
    // ═══════════════════════════════════════
    // PURPOSE: 메인 컨텐츠 레이아웃
    // ═══════════════════════════════════════
    private var mainContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg + 4) {
            headerSection
            progressSection
            currentStepModal
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }

    // MARK: - Header Section
    // ═══════════════════════════════════════
    // PURPOSE: 헤더 영역 (제목)
    // ═══════════════════════════════════════
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("회원가입")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    // MARK: - Progress Section
    // ═══════════════════════════════════════
    // PURPOSE: 진행 상태 표시
    // ═══════════════════════════════════════
    private var progressSection: some View {
        ProgressIndicator(
            totalSteps: SignUpViewModel.SignUpStep.allCases.count,
            currentStep: viewModel.currentStep.rawValue,
            stepTitles: stepTitles
        )
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }

    // MARK: - Current Step Modal
    // ═══════════════════════════════════════
    // PURPOSE: 현재 단계에 맞는 모달 표시
    // NOTE: 뷰빌더는 여러개의 뷰를 하나로 통합해서 각 상황에 맞는 뷰를 사용하게함
    // ═══════════════════════════════════════
    @ViewBuilder
    private var currentStepModal: some View {
        switch viewModel.currentStep {
        case .username:
            UsernameInputModal(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

        case .email:
            EmailInputModal(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

        case .password:
            PasswordSetupModal(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

        case .phoneNumber:
            PhoneNumberInputModal(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

        case .security:
            SecurityQuestionModal(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

        case .completion:
            CompletionModal(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }

    // MARK: - Helper Functions
    // ═══════════════════════════════════════
    // PURPOSE: 단계별 제목 반환
    // ═══════════════════════════════════════
    private func stepTitle(for step: SignUpViewModel.SignUpStep) -> String {
        switch step {
        case .username: return "아이디"
        case .email: return "이메일"
        case .password: return "비밀번호"
        case .phoneNumber: return "전화번호"
        case .security: return "보안질문"
        case .completion: return "완료"
        }
    }

    private var stepTitles: [String] {
        return SignUpViewModel.SignUpStep.allCases.map { stepTitle(for: $0) }
    }
}
