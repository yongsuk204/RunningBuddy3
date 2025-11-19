import SwiftUI
import Foundation
import Combine

// Purpose: 이메일 입력 및 유효성 검사를 위한 모달
// MARK: - 함수 목록
/*
 * UI Components
 * - headerSection: 헤더 영역 (제목 및 정보 버튼)
 * - emailInputSection: 이메일 입력 필드
 * - navigationSection: 다음/뒤로가기 버튼
 *
 * Validation Methods
 * - handleEmailChange(): 이메일 변경 시 실시간 형식 검증 (중복 체크는 Firebase Auth가 자동 처리)
 */
struct EmailInputModal: View {

    // MARK: - Properties

    // Purpose: 회원가입 전체 상태 및 데이터 관리 (이메일 입력값, 검증 상태 등)
    @ObservedObject var viewModel: SignUpViewModel

    // Purpose: 이메일 형식 검증을 위한 유효성 검사 서비스 (모달 내부에서만 사용)
    private let emailValidator = EmailValidator.shared

    // Purpose: 이메일 정보 도움말 알림창 표시 여부 (내부 UI 상태)
    @State private var showingEmailInfo = false

    // Purpose: 이메일 입력 필드의 포커스 상태 관리 (내부 UI 제어, 키보드 표시/숨김)
    @FocusState private var focusedField: Field?

    // MARK: - Focus Field Enum

    private enum Field: Hashable {
        case email
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            emailInputSection
            Spacer()
            navigationSection
        }
        .padding(30)
        .modalBackgroundStyle()
        .padding(.horizontal, 20)
        .onAppear {
            focusedField = .email
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Text("이메일")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showingEmailInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Text("아이디로 사용할 이메일을 입력해 주세요")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 10)
        }
        .alert("이메일 입력", isPresented: $showingEmailInfo) {
            Button("확인") { }
        } message: {
            Text("\n• 허용된 이메일 서비스\ngmail, naver, daum, nate, yahoo\n• 예시) user@gmail.com")
        }
    }

    // MARK: - Email Input Section

    private var emailInputSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 20)

                TextField("", text: $viewModel.signUpData.email)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .onChange(of: viewModel.signUpData.email) { _, newValue in
                        handleEmailChange(newValue)
                    }

                Spacer()

                ValidationFeedbackIcon(status: viewModel.validationStates.emailStatus)
            }
            .inputFieldStyle()

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
        return viewModel.validationStates.emailStatus == .valid &&
               !viewModel.signUpData.email.isEmpty
    }

    // MARK: - Helper Methods

    // Purpose: 이메일 변경 시 형식 검증 (중복 체크는 회원가입 시 Firebase Auth가 자동 처리)
    private func handleEmailChange(_ newEmail: String) {
        // Step 1: 빈 문자열 처리
        guard !newEmail.isEmpty else {
            viewModel.validationStates.emailStatus = .none
            return
        }

        // Step 2: 이메일 형식 검증 (실시간)
        let validationResult = emailValidator.validateEmail(newEmail)

        // Step 3: 검증 결과에 따라 상태 변경
        viewModel.validationStates.emailStatus = validationResult.isValid ? .valid : .invalid
    }
}
