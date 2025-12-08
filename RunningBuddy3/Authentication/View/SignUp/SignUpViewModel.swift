import SwiftUI
import Combine

// Purpose: 순차적 모달 기반 회원가입 과정의 상태 관리 👈 모달순서가 어디인지, 모달별로 입력한 정보가뭔지 등등 상태관리
// MARK: - 함수 목록
/*
 * Data Models
 * - SignUpData: 회원가입 입력 데이터 구조체
 * - ValidationStates: 각 단계별 유효성 검사 상태 관리
 *
 * Note: 단계 전환은 각 모달에서 viewModel.currentStep을 직접 변경
 */
class SignUpViewModel: ObservableObject {

    // MARK: - Sign Up Steps
    // ═══════════════════════════════════════
    // PURPOSE: 회원가입 단계 정의 (0-3 순차 진행)
    // ═══════════════════════════════════════
    enum SignUpStep: Int, CaseIterable {
        case email = 0
        case password = 1
        case security = 2
        case completion = 3
    }

    // MARK: - Published Properties
    // ═══════════════════════════════════════
    // PURPOSE: UI 바인딩 상태 프로퍼티
    // ═══════════════════════════════════════
    @Published var currentStep: SignUpStep = .email
    @Published var signUpData = SignUpData()
    @Published var validationStates = ValidationStates()
    @Published var isLoading = false
    @Published var errorMessage = ""

    // MARK: - Sign Up Data Model
    // ═══════════════════════════════════════
    // PURPOSE: 회원가입 입력 데이터 구조체
    // ═══════════════════════════════════════
    struct SignUpData: Equatable {
        var email = ""
        var password = ""
        var confirmPassword = ""
        var selectedSecurityQuestion = ""
        var securityAnswer = ""

        // ═══════════════════════════════════════
        // PURPOSE: 모든 필드가 입력되었는지 확인
        // ═══════════════════════════════════════
        var isComplete: Bool {
            return !email.isEmpty &&
                   !password.isEmpty &&
                   !confirmPassword.isEmpty &&
                   !selectedSecurityQuestion.isEmpty &&
                   !securityAnswer.isEmpty
        }
    }

    // MARK: - Validation States
    // ═══════════════════════════════════════
    // PURPOSE: 각 단계별 유효성 검사 상태 관리
    // ═══════════════════════════════════════
    struct ValidationStates: Equatable {
        var emailStatus: ValidationFeedbackIcon.ValidationStatus = .none
        var passwordStatus: ValidationFeedbackIcon.ValidationStatus = .none
        var confirmPasswordStatus: ValidationFeedbackIcon.ValidationStatus = .none
        var passwordErrorMessage = ""
    }

}
