import SwiftUI
import Combine

// Purpose: 아이디 찾기 프로세스의 상태 관리 및 비즈니스 로직
// MARK: - 함수 목록
/*
 * State Management
 * - currentStep: 현재 진행 단계 (전화번호 입력 → SMS 인증 → 결과 표시)
 * - phoneNumber, verificationCode, foundEmail: 입력 데이터
 * - isLoading, showingAlert, alertMessage: UI 상태
 *
 * SMS Methods
 * - sendSMS(): SMS 인증번호 발송
 * - verifySMS(authManager:): SMS 인증번호 검증
 * - resendSMS(): SMS 인증번호 재발송
 * - startSMSTimer(): SMS 재발송 타이머 시작
 *
 * ID Recovery Methods
 * - findEmailByPhone(): 전화번호로 아이디 조회
 *
 * Helper Methods
 * - resetToPhoneInput(): 전화번호 입력 단계로 초기화
 * - showAlert(_:): Alert 표시
 * - showError(_:): 에러 Alert 표시
 * - maskEmail(_:): 이메일 마스킹 처리
 */

class FindEmailViewModel: ObservableObject {

    // MARK: - Step Enum

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

    // MARK: - Published Properties (UI Bindings)

    @Published var currentStep: FindStep = .phoneInput
    @Published var phoneNumber = ""
    @Published var verificationCode = ""
    @Published var foundEmail: String? = nil
    @Published var isLoading = false
    @Published var showingAlert = false
    @Published var alertMessage = ""

    // SMS 타이머 관련
    @Published var smsTimer = Constants.smsTimeout
    @Published var canResendSMS = false

    // MARK: - Private Properties

    private var smsCountdownTimer: Timer?

    // Services
    private let phoneNumberValidator = PhoneNumberValidator.shared
    private let userService = UserService.shared
    private let phoneVerificationService = PhoneVerificationService.shared

    // MARK: - Computed Properties

    /// SMS 인증번호가 완전히 입력되었는지 확인
    var isVerificationCodeComplete: Bool {
        verificationCode.count == Constants.verificationCodeLength
    }

    /// 전화번호가 유효한지 확인
    var isPhoneNumberValid: Bool {
        phoneNumberValidator.validatePhoneNumber(phoneNumber).isValid
    }

    // MARK: - Initializer

    init() {}

    // MARK: - Deinit

    deinit {
        smsCountdownTimer?.invalidate()
    }

    // MARK: - SMS Methods

    // ═══════════════════════════════════════
    // PURPOSE: SMS 인증번호 발송
    // ═══════════════════════════════════════
    func sendSMS() async {
        isLoading = true

        let result = await phoneVerificationService.sendVerificationCode(to: phoneNumber)

        switch result {
        case .success:
            await MainActor.run {
                currentStep = .smsVerification
                startSMSTimer()

                // 디버그 모드에서만 테스트 안내
                #if DEBUG
                showAlert("인증번호가 발송되었습니다. (테스트: +821012345678은 702060 입력)")
                #else
                showAlert("인증번호가 발송되었습니다.")
                #endif
            }

        case .failure(let error):
            await MainActor.run {
                showError(error)
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: SMS 인증번호 검증
    // ═══════════════════════════════════════
    func verifySMS(authManager: AuthenticationManager) async {
        isLoading = true

        let result = await phoneVerificationService.verifyCode(verificationCode, authManager: authManager)

        switch result {
        case .success:
            // 인증 성공 - 아이디 찾기
            await findEmailByPhone()

            // 임시 전화번호 인증 계정 삭제
            do {
                try await authManager.deleteCurrentAccount()
            } catch {
                print("⚠️ 계정 삭제 실패 (무시 가능): \(error.localizedDescription)")
            }

        case .failure(let error):
            await MainActor.run {
                showError(error)
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: SMS 인증번호 재발송
    // ═══════════════════════════════════════
    func resendSMS() async {
        let result = await phoneVerificationService.resendVerificationCode(to: phoneNumber)

        await MainActor.run {
            switch result {
            case .success:
                startSMSTimer()
                showAlert("인증번호가 재발송되었습니다.")

            case .failure(let error):
                showError(error)
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: SMS 재발송 타이머 시작 (60초)
    // ═══════════════════════════════════════
    func startSMSTimer() {
        smsTimer = Constants.smsTimeout
        canResendSMS = false

        smsCountdownTimer?.invalidate()
        smsCountdownTimer = Timer.scheduledTimer(withTimeInterval: Constants.timerInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.smsTimer > 0 {
                self.smsTimer -= 1
            } else {
                self.canResendSMS = true
                self.smsCountdownTimer?.invalidate()
            }
        }
    }

    // MARK: - ID Recovery Methods

    // ═══════════════════════════════════════
    // PURPOSE: 전화번호로 아이디 조회
    // ═══════════════════════════════════════
    func findEmailByPhone() async {
        do {
            let email = try await userService.findEmailByPhoneNumber(phoneNumber)

            await MainActor.run {
                if let email = email {
                    foundEmail = email
                    currentStep = .showResults
                    smsCountdownTimer?.invalidate()
                } else {
                    showAlert("해당 전화번호로 가입된 계정이 없습니다")
                }
            }
        } catch {
            await MainActor.run {
                print("⚠️ 아이디 검색 실패: \(error.localizedDescription)")
                showAlert("아이디 검색 중 오류가 발생했습니다")
            }
        }
    }

    // MARK: - Password Reset

    // ═══════════════════════════════════════
    // PURPOSE: 비밀번호 재설정 링크 발송
    // ═══════════════════════════════════════
    func sendPasswordResetEmail(to email: String, authManager: AuthenticationManager) async {
        isLoading = true

        await authManager.sendPasswordReset(email: email)

        await MainActor.run {
            // AuthenticationManager의 errorMessage 확인 후 alert로 표시
            if authManager.errorMessage.contains("재설정 이메일이 발송되었습니다") {
                alertMessage = "\(maskEmail(email))로\n비밀번호 재설정 링크가 발송되었습니다.\n\n이메일을 확인하여 비밀번호를 재설정해주세요."
            } else if !authManager.errorMessage.isEmpty {
                alertMessage = authManager.errorMessage
            } else {
                alertMessage = "비밀번호 재설정 링크 발송에 실패했습니다."
            }

            showingAlert = true
            isLoading = false

            // AuthenticationManager의 errorMessage 초기화
            authManager.errorMessage = ""
        }
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 전화번호 입력 단계로 초기화
    // ═══════════════════════════════════════
    func resetToPhoneInput() {
        currentStep = .phoneInput
        verificationCode = ""
        smsCountdownTimer?.invalidate()
    }

    // ═══════════════════════════════════════
    // PURPOSE: 처음부터 다시 시작
    // ═══════════════════════════════════════
    func resetAll() {
        currentStep = .phoneInput
        phoneNumber = ""
        verificationCode = ""
        foundEmail = nil
        smsCountdownTimer?.invalidate()
    }

    // ═══════════════════════════════════════
    // PURPOSE: 일반 Alert 표시
    // ═══════════════════════════════════════
    func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }

    // ═══════════════════════════════════════
    // PURPOSE: 에러 Alert 표시
    // ═══════════════════════════════════════
    func showError(_ error: Error) {
        alertMessage = phoneVerificationService.errorMessage ?? error.localizedDescription
        showingAlert = true
    }

    // ═══════════════════════════════════════
    // PURPOSE: 이메일 마스킹 처리
    // ═══════════════════════════════════════
    func maskEmail(_ email: String) -> String {
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
