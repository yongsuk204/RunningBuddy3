import SwiftUI

// Purpose: 휴대폰 인증을 통한 아이디 찾기
struct FindEmailView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FindEmailViewModel()

    // 포커스 관리
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case phoneNumber
        case verificationCode
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.clear
                .appGradientBackground()

            mainContent
        }
        .navigationBarTitleDisplayMode(.inline)
        .standardAlert(isPresented: $viewModel.showingAlert, message: viewModel.alertMessage) {
            if viewModel.currentStep == .showResults && viewModel.foundEmail != nil {
                dismiss()
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .onAppear {
            // Step 1: 이전 에러 메시지 초기화
            authManager.errorMessage = ""

            // Step 2: 전화번호 입력 필드에 포커스
            focusedField = .phoneNumber
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg + 4) {
            headerSection
            contentSection

            Spacer()

            navigationSection
        }
        .padding(DesignSystem.Spacing.xl - 10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(.ultraThinMaterial)
                .shadow(
                    color: DesignSystem.Shadow.strong.color,
                    radius: DesignSystem.Shadow.strong.radius,
                    x: DesignSystem.Shadow.strong.x,
                    y: DesignSystem.Shadow.strong.y
                )
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text(headerTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var headerTitle: String {
        switch viewModel.currentStep {
        case .phoneInput:
            return "아이디 찾기"
        case .smsVerification:
            return "본인 확인"
        case .showResults:
            return "찾은 아이디"
        }
    }

    private var headerSubtitle: String {
        switch viewModel.currentStep {
        case .phoneInput:
            return "가입 시 등록한 전화번호를 입력하세요"
        case .smsVerification:
            return "SMS로 발송된 인증번호를 입력하세요"
        case .showResults:
            return "다음 아이디로 가입되어 있습니다"
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.currentStep {
        case .phoneInput:
            phoneInputSection
        case .smsVerification:
            smsVerificationSection
        case .showResults:
            resultsSection
        }
    }

    // MARK: - Phone Input Section

    private var phoneInputSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm + 4) {
            HStack {
                Image(systemName: "phone")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: DesignSystem.Spacing.lg)

                TextField("", text: $viewModel.phoneNumber)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .focused($focusedField, equals: .phoneNumber)
                    .onChange(of: viewModel.phoneNumber) { _, newValue in
                        viewModel.phoneNumber = PhoneNumberValidator.shared.formatPhoneNumber(newValue)
                    }
            }
            .inputFieldStyle()
        }
    }

    // MARK: - SMS Verification Section

    private var smsVerificationSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // 인증번호 입력
            VStack(spacing: DesignSystem.Spacing.sm + 4) {
                HStack {
                    Image(systemName: "message")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: DesignSystem.Spacing.lg)

                    TextField("인증번호 6자리", text: $viewModel.verificationCode)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focusedField, equals: .verificationCode)
                        .onChange(of: viewModel.verificationCode) { _, newValue in
                            viewModel.verificationCode = String(newValue.filter { $0.isNumber }.prefix(6))
                        }

                    if viewModel.isVerificationCodeComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.success)
                    }
                }
                .inputFieldStyle()
            }

            // 타이머 및 재발송
            HStack {
                if viewModel.canResendSMS {
                    Button("인증번호 재발송") {
                        Task {
                            await viewModel.resendSMS()
                        }
                    }
                    .foregroundColor(DesignSystem.Colors.info)
                    .font(DesignSystem.Typography.caption)
                } else {
                    Text("재발송 가능: \(viewModel.smsTimer)초")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                Button("전화번호 변경") {
                    viewModel.resetToPhoneInput()
                }
                .foregroundColor(DesignSystem.Colors.warning)
                .font(DesignSystem.Typography.caption)
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            if let email = viewModel.foundEmail {
                // 이메일 찾음
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignSystem.Typography.iconLarge)
                    .foregroundColor(DesignSystem.Colors.success)

                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Text(email)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm + 4) {
            if viewModel.currentStep != .showResults {
                // phoneInput, smsVerification 단계: NavigationButtons 컴포넌트 사용
                NavigationButtons(
                    canGoBack: true,
                    canGoNext: true,
                    nextButtonTitle: nextButtonTitle,
                    isNextDisabled: !isNextButtonEnabled || viewModel.isLoading,
                    onBack: { handleBackAction() },
                    onNext: { Task { await handleNextAction() } }
                )
            } else if let email = viewModel.foundEmail {
                // showResults 단계: 커스텀 버튼 (비밀번호 재설정)
                VStack(spacing: DesignSystem.Spacing.sm + 4) {
                    // 비밀번호 재설정 버튼
                    Button {
                        Task {
                            await viewModel.sendPasswordResetEmail(to: email, authManager: authManager)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("비밀번호 재설정 이메일 발송")
                        }
                        .primaryButtonStyle(backgroundColor: DesignSystem.Colors.buttonPrimary)
                    }
                    .disabled(viewModel.isLoading)

                    // 다시 찾기 버튼
                    Button {
                        handleBackAction()
                    } label: {
                        Text("다시 찾기")
                            .secondaryButtonStyle()
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }

    private var nextButtonTitle: String {
        switch viewModel.currentStep {
        case .phoneInput:
            return viewModel.isLoading ? "발송 중..." : "인증번호 발송"
        case .smsVerification:
            return viewModel.isLoading ? "확인 중..." : "확인"
        case .showResults:
            return ""
        }
    }

    private var isNextButtonEnabled: Bool {
        switch viewModel.currentStep {
        case .phoneInput:
            return viewModel.isPhoneNumberValid
        case .smsVerification:
            return viewModel.isVerificationCodeComplete
        case .showResults:
            return false
        }
    }

    // MARK: - Actions

    private func handleBackAction() {
        switch viewModel.currentStep {
        case .phoneInput:
            dismiss()
        case .smsVerification:
            viewModel.resetToPhoneInput()
        case .showResults:
            viewModel.resetAll()
        }
    }

    private func handleNextAction() async {
        switch viewModel.currentStep {
        case .phoneInput:
            await viewModel.sendSMS()
            // SMS 발송 성공 시 자동으로 focusedField 변경
            if viewModel.currentStep == .smsVerification {
                focusedField = .verificationCode
            }
        case .smsVerification:
            await viewModel.verifySMS(authManager: authManager)
        case .showResults:
            break
        }
    }
}
