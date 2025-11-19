import SwiftUI
import Foundation
import Combine

// Purpose: 순차적 모달 기반 회원가입 과정의 상태 관리 👈 모달순서가 어디인지, 모달별로 입력한 정보가뭔지 등등 상태관리
// MARK: - 함수 목록
/*
 * Navigation Methods
 * - goToNextStep(): 다음 단계로 진행
 * - goToPreviousStep(): 이전 단계로 돌아가기
 * - canProceedToNextStep(): 다음 단계로 진행 가능한지 확인
 * - isCurrentStepValid(): 현재 단계의 유효성 검사 상태 확인 (private)
 *
 * Data Management
 * - resetAllData(): 모든 데이터 초기화 (회원가입 완료/취소 시 사용)
 *
 * Data Models
 * - SignUpData: 회원가입 입력 데이터 구조체
 * - ValidationStates: 각 단계별 유효성 검사 상태 관리
 */
class SignUpViewModel: ObservableObject {

    // MARK: - Sign Up Steps

    enum SignUpStep: Int, CaseIterable {
        case username = 0
        case email = 1
        case password = 2
        case phoneNumber = 3
        case security = 4
        case completion = 5
    }

    // MARK: - Published Properties

    @Published var currentStep: SignUpStep = .username
    @Published var signUpData = SignUpData()
    @Published var validationStates = ValidationStates()
    @Published var isLoading = false
    @Published var errorMessage = ""

    // MARK: - Sign Up Data Model

    struct SignUpData: Equatable {
        var username = ""
        var email = ""
        var password = ""
        var confirmPassword = ""
        var phoneNumber = ""
        var selectedSecurityQuestion = ""
        var securityAnswer = ""

        // Purpose: 모든 필드가 입력되었는지 확인
        var isComplete: Bool {
            return !username.isEmpty &&
                   !email.isEmpty &&
                   !password.isEmpty &&
                   !confirmPassword.isEmpty &&
                   !phoneNumber.isEmpty &&
                   !selectedSecurityQuestion.isEmpty &&
                   !securityAnswer.isEmpty
        }
    }

    // MARK: - Validation States

    struct ValidationStates: Equatable {
        var usernameStatus: ValidationFeedbackIcon.ValidationStatus = .none
        var emailStatus: ValidationFeedbackIcon.ValidationStatus = .none
        var passwordStatus: ValidationFeedbackIcon.ValidationStatus = .none
        var confirmPasswordStatus: ValidationFeedbackIcon.ValidationStatus = .none
        var phoneNumberStatus: ValidationFeedbackIcon.ValidationStatus = .none
        var passwordErrorMessage = ""
    }

    // MARK: - Navigation Methods

    // Purpose: 다음 단계로 진행
    func goToNextStep() {
        guard canProceedToNextStep() else { return }

        if let nextStep = SignUpStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
    }

    // Purpose: 이전 단계로 돌아가기
    func goToPreviousStep() {
        if let previousStep = SignUpStep(rawValue: currentStep.rawValue - 1) {
            currentStep = previousStep
        }
    }


    // Purpose: 다음 단계로 진행 가능한지 확인
    func canProceedToNextStep() -> Bool {
        return isCurrentStepValid(for: currentStep)
    }

    // Purpose: 현재 단계의 유효성 검사 상태 확인
    private func isCurrentStepValid(for step: SignUpStep) -> Bool {
        switch step {
        case .username:
            return validationStates.usernameStatus == .valid
        case .email:
            return validationStates.emailStatus == .valid
        case .password:
            return validationStates.passwordStatus == .valid && validationStates.confirmPasswordStatus == .valid
        case .phoneNumber:
            return validationStates.phoneNumberStatus == .valid
        case .security:
            return true // 보안질문은 별도 검증 로직
        case .completion:
            return true
        }
    }



    // MARK: - Data Reset
    // TODO: 적절한 시기에 초기화함수 호출해야함 -> 지금은 아직 사용하고있지 않음

    // Purpose: 모든 데이터 초기화
    func resetAllData() {
        currentStep = .email
        signUpData = SignUpData()
        validationStates = ValidationStates()
        errorMessage = ""
        isLoading = false
    }
}
