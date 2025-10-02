import SwiftUI
import FirebaseFirestore

// Purpose: 휴대폰 인증을 통한 이메일 찾기
struct FindEmailView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    // Purpose: 찾기 프로세스 단계 관리
    enum FindStep {
        case phoneInput         // 전화번호 입력
        case smsVerification   // SMS 인증
        case showResults       // 결과 표시
    }

    // MARK: - State Properties

    @State private var currentStep: FindStep = .phoneInput
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var sessionInfo = ""
    @State private var foundEmails: [String] = []
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // SMS 타이머 관련
    @State private var smsTimer = 60
    @State private var canResendSMS = false
    @State private var smsCountdownTimer: Timer?

    // 포커스 관리
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case phoneNumber
        case verificationCode
    }

    // 서비스 인스턴스
    private let phoneNumberValidator = PhoneNumberValidator.shared
    private let userService = UserService.shared
    @StateObject private var phoneAuthService = PhoneAuthService.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // 헤더
                headerSection

                // 단계별 내용
                Group {
                    switch currentStep {
                    case .phoneInput:
                        phoneInputSection
                    case .smsVerification:
                        smsVerificationSection
                    case .showResults:
                        resultsSection
                    }
                }

                Spacer()

                // 네비게이션 버튼
                navigationSection
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 20)
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
            focusedField = .phoneNumber
        }
        .onDisappear {
            smsCountdownTimer?.invalidate()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(headerTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
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

    // MARK: - Phone Input Section

    private var phoneInputSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "phone")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 20)

                TextField("010-1234-5678", text: $phoneNumber)
                    .foregroundColor(.white)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .focused($focusedField, equals: .phoneNumber)
                    .onChange(of: phoneNumber) { _, newValue in
                        phoneNumber = phoneNumberValidator.formatPhoneNumber(newValue)
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )

            Text("회원가입 시 등록한 전화번호를 입력해주세요")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - SMS Verification Section

    private var smsVerificationSection: some View {
        VStack(spacing: 20) {
            // 인증번호 입력
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "message")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    TextField("인증번호 6자리", text: $verificationCode)
                        .foregroundColor(.white)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focusedField, equals: .verificationCode)
                        .onChange(of: verificationCode) { _, newValue in
                            verificationCode = String(newValue.filter { $0.isNumber }.prefix(6))
                        }

                    if verificationCode.count == 6 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )

                Text("\(phoneNumber)로 발송된 인증번호를 입력하세요")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            // 타이머 및 재발송
            HStack {
                if canResendSMS {
                    Button("인증번호 재발송") {
                        Task {
                            let _ = await phoneAuthService.resendVerificationCode(to: phoneNumber)
                            startSMSTimer()
                        }
                    }
                    .foregroundColor(.blue)
                    .font(.caption)
                } else {
                    Text("재발송 가능: \(smsTimer)초")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Button("전화번호 변경") {
                    currentStep = .phoneInput
                    verificationCode = ""
                    sessionInfo = ""
                    smsCountdownTimer?.invalidate()
                }
                .foregroundColor(.orange)
                .font(.caption)
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: 20) {
            if foundEmails.isEmpty {
                // 이메일 없음
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.red.opacity(0.6))

                Text("등록된 이메일이 없습니다")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("해당 전화번호로 가입된 계정이 없습니다")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                // 이메일 찾음
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                VStack(spacing: 10) {
                    ForEach(foundEmails, id: \.self) { email in
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white.opacity(0.6))

                            Text(maskEmail(email))
                                .font(.headline)
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        HStack(spacing: 16) {
            // 뒤로/다시 찾기 버튼
            Button {
                handleBackAction()
            } label: {
                Text(backButtonTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }

            // 다음/로그인 버튼
            if currentStep != .showResults || !foundEmails.isEmpty {
                Button {
                    Task {
                        await handleNextAction()
                    }
                } label: {
                    Text(nextButtonTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isNextButtonEnabled ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .disabled(!isNextButtonEnabled || isLoading)
            } else if foundEmails.isEmpty {
                // 회원가입 버튼
                NavigationLink {
                    SignUpView()
                } label: {
                    Text("회원가입")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
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
            return "로그인 하기"
        }
    }

    private var isNextButtonEnabled: Bool {
        switch currentStep {
        case .phoneInput:
            return phoneNumberValidator.validatePhoneNumber(phoneNumber).isValid
        case .smsVerification:
            return verificationCode.count == 6
        case .showResults:
            return !foundEmails.isEmpty
        }
    }

    // MARK: - Actions

    private func handleBackAction() {
        switch currentStep {
        case .phoneInput:
            dismiss()
        case .smsVerification:
            currentStep = .phoneInput
            verificationCode = ""
            sessionInfo = ""
            smsCountdownTimer?.invalidate()
        case .showResults:
            // 처음부터 다시 시작
            currentStep = .phoneInput
            phoneNumber = ""
            verificationCode = ""
            sessionInfo = ""
            foundEmails = []
        }
    }

    private func handleNextAction() async {
        switch currentStep {
        case .phoneInput:
            await sendSMS()
        case .smsVerification:
            await verifySMS()
        case .showResults:
            dismiss()
        }
    }

    // MARK: - SMS Functions

    private func sendSMS() async {
        isLoading = true

        // Purpose: Firebase Phone Auth 사용
        let result = await phoneAuthService.sendVerificationCode(to: phoneNumber)

        switch result {
        case .success(let verificationID):
            sessionInfo = verificationID
            currentStep = .smsVerification
            focusedField = .verificationCode
            startSMSTimer()

            // 디버그 모드에서만 테스트 안내
            #if DEBUG
            alertMessage = "인증번호가 발송되었습니다. (테스트: +821012345678은 702060 입력)"
            #else
            alertMessage = "인증번호가 발송되었습니다."
            #endif
            showingAlert = true

        case .failure(let error):
            alertMessage = phoneAuthService.errorMessage ?? error.localizedDescription
            showingAlert = true
        }

        isLoading = false
    }

    private func verifySMS() async {
        isLoading = true

        // Purpose: Firebase Phone Auth로 인증 코드 검증 (리스너 비활성화로 화면 전환 방지)
        let result = await phoneAuthService.verifyCode(verificationCode, authManager: authManager)

        switch result {
        case .success(_):
            // 인증 성공 - 이메일 찾기
            await findEmailsByPhone()

            // 임시 전화번호 인증 계정 삭제
            do {
                try await authManager.deleteCurrentAccount()
            } catch {
                print("⚠️ 계정 삭제 실패 (무시 가능): \(error.localizedDescription)")
            }

        case .failure(let error):
            alertMessage = phoneAuthService.errorMessage ?? error.localizedDescription
            showingAlert = true
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
            alertMessage = "이메일 검색 중 오류가 발생했습니다"
            showingAlert = true
        }
    }

    private func startSMSTimer() {
        smsTimer = 60
        canResendSMS = false

        smsCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if smsTimer > 0 {
                smsTimer -= 1
            } else {
                canResendSMS = true
                smsCountdownTimer?.invalidate()
            }
        }
    }

    // MARK: - Helper Functions

    private func maskEmail(_ email: String) -> String {
        let components = email.split(separator: "@")
        guard components.count == 2 else { return email }

        let username = String(components[0])
        let domain = String(components[1])

        if username.count <= 3 {
            return "***@\(domain)"
        }

        let visibleChars = 3
        let maskedPart = String(repeating: "*", count: username.count - visibleChars)
        let visiblePart = username.prefix(visibleChars)

        return "\(visiblePart)\(maskedPart)@\(domain)"
    }

}
