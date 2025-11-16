import SwiftUI
import Foundation
import Combine

// Purpose: 비밀번호 입력과 확인을 통합한 모달
// MARK: - 함수 목록
/*
 * UI Components
 * - headerSection: 헤더 영역 (제목 및 정보 버튼)
 * - passwordInputSection: 비밀번호 입력 필드
 * - confirmPasswordSection: 비밀번호 확인 입력 필드
 * - navigationSection: 이전/다음 버튼
 *
 * Validation Methods
 * - handlePasswordChange(): 비밀번호 변경 시 정책 검증 및 상태 업데이트
 * - handleConfirmPasswordChange(): 비밀번호 확인 변경 시 일치 여부 검증
 * - canProceedToNext: 다음 단계 진행 가능 여부 확인
 */
struct PasswordSetupModal: View {

    // MARK: - Properties

    @ObservedObject var viewModel: SignUpViewModel
    @FocusState private var focusedField: Field?
    @State private var showingPasswordInfo = false

    // MARK: - Focus Field Enum

    private enum Field: Hashable {
        case password
        case confirmPassword
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            headerSection

            VStack(spacing: 10) {
                passwordInputSection
                confirmPasswordSection
            }
            .padding(.top, -10)

            Spacer()
            navigationSection
        }
        .padding(30)
        .background(ModalBackground())
        .padding(.horizontal, 20)
        .onAppear {
            focusedField = .password
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Text("비밀번호")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showingPasswordInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Text("안전한 비밀번호를 설정해주세요")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .alert("비밀번호 설정", isPresented: $showingPasswordInfo) {
            Button("확인") { }
        } message: {
            Text("\n• 비밀번호는 10자 이상 16자 이하로 설정해주세요\n• 영문 대소문자, 숫자, 특수문자를 포함해야 합니다\n• 예시) qwer1234!@#$")
        }
    }

    // MARK: - Password Input Section

    private var passwordInputSection: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 20)

                SecureField("", text: $viewModel.signUpData.password)
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .password)
                    .onChange(of: viewModel.signUpData.password) { _, newValue in
                        handlePasswordChange(newValue)
                    }
                    .onSubmit {
                        focusedField = .confirmPassword
                    }

                Spacer()

                ValidationFeedbackIcon(status: viewModel.validationStates.passwordStatus)
            }
            .padding()
            .background(FieldBackground())
        }
    }

    // MARK: - Confirm Password Section

    private var confirmPasswordSection: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 20)

                SecureField("", text: $viewModel.signUpData.confirmPassword)
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .confirmPassword)
                    .onChange(of: viewModel.signUpData.confirmPassword) { _, newValue in
                        handleConfirmPasswordChange(newValue)
                    }

                Spacer()

                ValidationFeedbackIcon(status: viewModel.validationStates.confirmPasswordStatus)
            }
            .padding()
            .background(FieldBackground())
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        NavigationButtons(
            canGoBack: true,
            canGoNext: true,
            nextButtonTitle: "다음",
            isNextDisabled: !canProceedToNext,
            onBack: {
                viewModel.goToPreviousStep()
            },
            onNext: {
                viewModel.goToNextStep()
            }
        )
    }

    // MARK: - Computed Properties

    // Purpose: 다음 단계로 진행 가능한지 확인
    private var canProceedToNext: Bool {
        return viewModel.validationStates.passwordStatus == .valid &&
               viewModel.validationStates.confirmPasswordStatus == .valid &&
               !viewModel.signUpData.password.isEmpty &&
               !viewModel.signUpData.confirmPassword.isEmpty
    }

    // MARK: - Helper Methods

    // Purpose: 비밀번호 변경 시 유효성 검사
    private func handlePasswordChange(_ newPassword: String) {
        // 빈 값 처리
        guard !newPassword.isEmpty else {
            viewModel.validationStates.passwordStatus = .none
            viewModel.validationStates.passwordErrorMessage = ""
            viewModel.validationStates.confirmPasswordStatus = .none
            return
        }

        // PasswordValidator를 사용한 정책 검증
        let validationResult = PasswordValidator.validatePolicy(newPassword)

        if validationResult.isValid {
            viewModel.validationStates.passwordStatus = .valid
            viewModel.validationStates.passwordErrorMessage = ""
        } else {
            viewModel.validationStates.passwordStatus = .invalid
            viewModel.validationStates.passwordErrorMessage = validationResult.errorMessage
        }

        // 확인 비밀번호가 입력되어 있다면 재검증
        if !viewModel.signUpData.confirmPassword.isEmpty {
            handleConfirmPasswordChange(viewModel.signUpData.confirmPassword)
        }
    }

    // Purpose: 비밀번호 확인 변경 시 검증
    private func handleConfirmPasswordChange(_ newConfirmPassword: String) {
        guard !newConfirmPassword.isEmpty else {
            viewModel.validationStates.confirmPasswordStatus = .none
            return
        }

        // 비밀번호와 일치 여부 확인
        if newConfirmPassword == viewModel.signUpData.password && !viewModel.signUpData.password.isEmpty {
            viewModel.validationStates.confirmPasswordStatus = .valid
        } else {
            viewModel.validationStates.confirmPasswordStatus = .invalid
        }
    }
}
