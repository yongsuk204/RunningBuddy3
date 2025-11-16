import SwiftUI
import FirebaseAuth

// Purpose: 순차적 모달 기반 회원가입 메인 컨테이너 뷰
struct SignUpView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var viewModel = SignUpViewModel()

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션 - Theme applied
            LinearGradient(
                colors: [
                    themeManager.gradientStart.opacity(DesignSystem.Opacity.semiMedium),
                    themeManager.gradientEnd.opacity(DesignSystem.Opacity.semiMedium)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            mainContent
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg + 4) {
            headerSection
            progressSection
            currentStepModal
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("회원가입")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        ProgressIndicator(
            totalSteps: SignUpViewModel.SignUpStep.allCases.count,
            currentStep: viewModel.currentStep.rawValue,
            stepTitles: stepTitles
        )
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }

    // MARK: - Current Step Modal

    @ViewBuilder
    private var currentStepModal: some View {
        switch viewModel.currentStep {
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

    private func stepTitle(for step: SignUpViewModel.SignUpStep) -> String {
        switch step {
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
