import SwiftUI

// Purpose: 휴대폰 인증을 통한 이메일 찾기
struct FindEmailView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss // 화면을 닫는 기능
    @StateObject private var themeManager = ThemeManager.shared

    // Purpose: 찾기 프로세스 단계 관리
    enum FindStep {
        case phoneInput         // 전화번호 입력
        case smsVerification   // SMS 인증
        case showResults       // 결과 표시
    }

    // MARK: - Constants

    private enum Constants {
        static let smsTimeout = 60  // SMS 재발송 타이머 시간 (초)
        static let timerInterval = 1.0  // 타이머 갱신 간격 (초)
        static let emailMaskThreshold = 3  // 이메일 마스킹 임계값 (문자 수)
        static let verificationCodeLength = 6  // SMS 인증번호 길이
    }

    // MARK: - State Properties

    @State private var currentStep: FindStep = .phoneInput
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var foundEmails: [String] = []
    @State private var selectedEmail: String? = nil
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // SMS 타이머 관련
    @State private var smsTimer = Constants.smsTimeout
    @State private var canResendSMS = false
    @State private var smsCountdownTimer: Timer?

    // 포커스 관리
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case phoneNumber
        case verificationCode
    }

    // 회원가입 뷰에서만 사용하는 서비스 인스턴스
    private let phoneNumberValidator = PhoneNumberValidator.shared
    private let userService = UserService.shared
    private let phoneVerificationService = PhoneVerificationService.shared

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
        .alert("알림", isPresented: $showingAlert) {
            Button("확인") {
                if currentStep == .showResults && !foundEmails.isEmpty {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .onAppear {
            // Step 1: 이전 에러 메시지 초기화 (다른 뷰에서 남은 메시지 방지)
            authManager.errorMessage = ""

            // Step 2: 전화번호 입력 필드에 포커스
            focusedField = .phoneNumber
        }
        .onDisappear {
            smsCountdownTimer?.invalidate()
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
        switch currentStep {
        case .phoneInput:
            return "이메일 찾기"
        case .smsVerification:
            return "본인 확인"
        case .showResults:
            return foundEmails.isEmpty ? "검색 결과" : "찾은 이메일"
        }
    }

    private var headerSubtitle: String {
        switch currentStep {
        case .phoneInput:
            return "가입 시 등록한 전화번호를 입력하세요"
        case .smsVerification:
            return "SMS로 발송된 인증번호를 입력하세요"
        case .showResults:
            return foundEmails.isEmpty ? "등록된 이메일이 없습니다" : "다음 이메일로 가입되어 있습니다"
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        switch currentStep {
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

                TextField("", text: $phoneNumber)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .focused($focusedField, equals: .phoneNumber)
                    .onChange(of: phoneNumber) { _, newValue in
                        phoneNumber = phoneNumberValidator.formatPhoneNumber(newValue)
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

                    TextField("인증번호 6자리", text: $verificationCode)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focusedField, equals: .verificationCode)
                        .onChange(of: verificationCode) { _, newValue in
                            verificationCode = String(newValue.filter { $0.isNumber }.prefix(Constants.verificationCodeLength))
                        }

                    if verificationCode.count == Constants.verificationCodeLength {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.success)
                    }
                }
                .inputFieldStyle()

                Text("\(phoneNumber)로 발송된 인증번호를 입력하세요")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            // 타이머 및 재발송
            HStack {
                if canResendSMS {
                    Button("인증번호 재발송") {
                        Task {
                            await resendSMS()
                        }
                    }
                    .foregroundColor(DesignSystem.Colors.info)
                    .font(DesignSystem.Typography.caption)
                } else {
                    Text("재발송 가능: \(smsTimer)초")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                Button("전화번호 변경") {
                    resetToPhoneInput()
                }
                .foregroundColor(DesignSystem.Colors.warning)
                .font(DesignSystem.Typography.caption)
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            if foundEmails.isEmpty {
                // 이메일 없음
                Image(systemName: "xmark.circle.fill")
                    .font(DesignSystem.Typography.iconLarge)
                    .foregroundColor(DesignSystem.Colors.error.opacity(DesignSystem.Opacity.semiMedium))

                Text("등록된 이메일이 없습니다")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            } else {
                // 이메일 찾음
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignSystem.Typography.iconLarge)
                    .foregroundColor(DesignSystem.Colors.success)

                VStack(spacing: DesignSystem.Spacing.sm + 2) {
                    ForEach(foundEmails, id: \.self) { email in
                        Button {
                            selectedEmail = email
                        } label: {
                            HStack {
                                // 체크 아이콘
                                Image(systemName: selectedEmail == email ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedEmail == email ? DesignSystem.Colors.success : DesignSystem.Colors.textTertiary)
                                    .font(DesignSystem.Typography.iconSmall)

                                Image(systemName: "envelope.fill")
                                    .foregroundColor(DesignSystem.Colors.textTertiary)

                                Text(maskEmail(email))
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
            }
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm + 4) {
            // 다음 버튼 (이메일 찾기 완료 전까지만 표시)
            if currentStep != .showResults {
                Button {
                    Task {
                        await handleNextAction()
                    }
                } label: {
                    Text(nextButtonTitle)
                        .primaryButtonStyle(
                            backgroundColor: isNextButtonEnabled ? DesignSystem.Colors.buttonPrimary : DesignSystem.Colors.buttonDisabled
                        )
                }
                .disabled(!isNextButtonEnabled || isLoading)
            } else if foundEmails.isEmpty {
                // 회원가입 버튼 (이메일이 없을 때만)
                NavigationLink {
                    SignUpView()
                } label: {
                    Text("회원가입")
                        .primaryButtonStyle(backgroundColor: DesignSystem.Colors.buttonSuccess)
                }
            } else {
                // 비밀번호 재설정 버튼 (이메일을 찾았을 때)
                Button {
                    guard let email = selectedEmail else { return }
                    Task {
                        await sendPasswordResetEmail(to: email)
                    }
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("비밀번호 재설정 이메일 발송")
                    }
                    .primaryButtonStyle(
                        backgroundColor: selectedEmail != nil ? DesignSystem.Colors.buttonPrimary : DesignSystem.Colors.buttonDisabled
                    )
                }
                .disabled(selectedEmail == nil || isLoading)
            }

            // 뒤로/다시 찾기 버튼
            Button {
                handleBackAction()
            } label: {
                Text(backButtonTitle)
                    .secondaryButtonStyle()
            }
        }
    }

    private var backButtonTitle: String {
        switch currentStep {
        case .phoneInput:
            return "취소"
        case .smsVerification:
            return "이전"
        case .showResults:
            return "다시 찾기"
        }
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case .phoneInput:
            return isLoading ? "발송 중..." : "인증번호 발송"
        case .smsVerification:
            return isLoading ? "확인 중..." : "확인"
        case .showResults:
            return "" // navigationSection에서 이미 필터링되어 호출되지 않음
        }
    }

    private var isNextButtonEnabled: Bool {
        switch currentStep {
        case .phoneInput:
            return phoneNumberValidator.validatePhoneNumber(phoneNumber).isValid
        case .smsVerification:
            return verificationCode.count == Constants.verificationCodeLength
        case .showResults:
            return false // navigationSection에서 이미 필터링되어 호출되지 않음
        }
    }

    // MARK: - Actions

    private func handleBackAction() {
        switch currentStep {
        case .phoneInput:
            dismiss()
        case .smsVerification:
            resetToPhoneInput()
        case .showResults:
            // 처음부터 다시 시작
            currentStep = .phoneInput
            phoneNumber = ""
            verificationCode = ""
            foundEmails = []
            selectedEmail = nil
        }
    }

    private func handleNextAction() async {
        switch currentStep {
        case .phoneInput:
            await sendSMS()
        case .smsVerification:
            await verifySMS()
        case .showResults:
            break // 더 이상 사용하지 않음
        }
    }

    // MARK: - Password Reset

    // Purpose: 비밀번호 재설정 이메일 발송
    private func sendPasswordResetEmail(to email: String) async {
        isLoading = true

        await authManager.sendPasswordReset(email: email)

        // AuthenticationManager의 errorMessage 확인 후 alert로 표시
        if authManager.errorMessage.contains("재설정 이메일이 발송되었습니다") {
            alertMessage = "\(maskEmail(email))로\n비밀번호 재설정 이메일이 발송되었습니다.\n\n이메일을 확인하여 비밀번호를 재설정해주세요."
        } else if !authManager.errorMessage.isEmpty {
            alertMessage = authManager.errorMessage
        } else {
            alertMessage = "비밀번호 재설정 이메일 발송에 실패했습니다."
        }

        // AuthenticationManager의 errorMessage 초기화 (LoginView에 영향 없도록)
        // Note: LoginView는 .onAppear에서 메시지를 초기화하므로 중복 방어 필요
        await MainActor.run {
            authManager.errorMessage = ""
        }

        showingAlert = true
        isLoading = false
    }

    // MARK: - SMS Functions

    // Purpose: 인증번호 재발송 처리
    private func resendSMS() async {
        let result = await phoneVerificationService.resendVerificationCode(to: phoneNumber)

        switch result {
        case .success:
            startSMSTimer()
            showAlert("인증번호가 재발송되었습니다.")

        case .failure(let error):
            showError(error)
        }
    }

    private func sendSMS() async {
        isLoading = true

        // Purpose: Firebase Phone Auth 사용
        let result = await phoneVerificationService.sendVerificationCode(to: phoneNumber)

        switch result {
        case .success:
            currentStep = .smsVerification
            focusedField = .verificationCode
            startSMSTimer()

            // 디버그 모드에서만 테스트 안내
            #if DEBUG
            showAlert("인증번호가 발송되었습니다. (테스트: +821012345678은 702060 입력)")
            #else
            showAlert("인증번호가 발송되었습니다.")
            #endif

        case .failure(let error):
            showError(error)
        }

        isLoading = false
    }

    // Purpose: Firebase Phone Auth로 인증 코드 검증
    private func verifySMS() async {
        isLoading = true

        // Purpose: Firebase Phone Auth로 인증 코드 검증 (리스너 비활성화로 화면 전환 방지)
        let result = await phoneVerificationService.verifyCode(verificationCode, authManager: authManager)

        switch result {
        case .success:
            // 인증 성공 - 이메일 찾기
            await findEmailsByPhone()

            // 임시 전화번호 인증 계정 삭제
            do {
                try await authManager.deleteCurrentAccount()
            } catch {
                print("⚠️ 계정 삭제 실패 (무시 가능): \(error.localizedDescription)")
            }

        case .failure(let error):
            showError(error)
        }

        isLoading = false
    }

    private func findEmailsByPhone() async {
        // Firestore에서 전화번호로 이메일 찾기
        do {
            let emails = try await userService.findEmailsByPhoneNumber(phoneNumber)
            foundEmails = emails
            currentStep = .showResults
            smsCountdownTimer?.invalidate()
        } catch {
            print("⚠️ 이메일 검색 실패: \(error.localizedDescription)")
            showAlert("이메일 검색 중 오류가 발생했습니다")
        }
    }

    private func startSMSTimer() {
        smsTimer = Constants.smsTimeout
        canResendSMS = false

        smsCountdownTimer = Timer.scheduledTimer(withTimeInterval: Constants.timerInterval, repeats: true) { _ in
            if smsTimer > 0 {
                smsTimer -= 1
            } else {
                canResendSMS = true
                smsCountdownTimer?.invalidate()
            }
        }
    }

    // MARK: - Helper Functions

    // Purpose: SMS 인증 단계를 전화번호 입력 단계로 초기화
    private func resetToPhoneInput() {
        currentStep = .phoneInput
        verificationCode = ""
        smsCountdownTimer?.invalidate()
    }

    // Purpose: 에러 메시지 표시 (중복 제거)
    private func showError(_ error: Error) {
        alertMessage = phoneVerificationService.errorMessage ?? error.localizedDescription
        showingAlert = true
    }

    // Purpose: 일반 Alert 메시지 표시 (중복 제거)
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }

    private func maskEmail(_ email: String) -> String {
        let components = email.split(separator: "@")
        guard components.count == 2 else { return email }

        let username = String(components[0])
        let domain = String(components[1])

        if username.count <= Constants.emailMaskThreshold {
            return "***@\(domain)"
        }

        let visibleChars = Constants.emailMaskThreshold
        let maskedPart = String(repeating: "*", count: username.count - visibleChars)
        let visiblePart = username.prefix(visibleChars)

        return "\(visiblePart)\(maskedPart)@\(domain)"
    }

}
