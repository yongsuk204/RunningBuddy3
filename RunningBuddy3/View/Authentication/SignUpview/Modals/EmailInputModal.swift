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
 * - handleEmailChange(): 이메일 변경 시 실시간 검증, 디바운싱, 상세 형식 검증 및 중복 체크
 */
struct EmailInputModal: View {

    // MARK: - Properties

    // Purpose: 회원가입 전체 상태 및 데이터 관리 (이메일 입력값, 검증 상태 등)
    @ObservedObject var viewModel: SignUpViewModel

    // Purpose: Firebase 인증 관리자 (회원가입 처리용)
    @EnvironmentObject var authManager: AuthenticationManager

    // Purpose: 이메일 중복 체크를 위한 Firestore 사용자 서비스 (모달 내부에서만 사용)
    private let userService = UserService.shared

    // Purpose: 이메일 형식 검증을 위한 유효성 검사 서비스 (모달 내부에서만 사용)
    private let emailValidator = EmailValidator.shared

    // Purpose: 이메일 정보 도움말 알림창 표시 여부 (내부 UI 상태)
    @State private var showingEmailInfo = false

    // Purpose: 이메일 입력 디바운싱을 위한 타이머 (0.5초 지연 후 검증 실행, 내부 제어용)
    @State private var emailCheckTimer: Timer?

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
        .background(ModalBackground())
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
            Text("\n• 허용된 이메일 서비스: gmail, naver, daum, nate, yahoo\n• 예시) user@gmail.com")
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
                    .textContentType(.oneTimeCode)
                    .focused($focusedField, equals: .email)
                    .onChange(of: viewModel.signUpData.email) { _, newValue in
                        handleEmailChange(newValue)
                    }

                Spacer()

                ValidationFeedbackIcon(status: viewModel.validationStates.emailStatus)
            }
            .padding()
            .background(FieldBackground())

        }
    }


    // MARK: - Validation Feedback Section

    @ViewBuilder
    private var validationFeedbackSection: some View {
        VStack(spacing: 8) {
            switch viewModel.validationStates.emailStatus {
            case .checking:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("이메일 중복 확인 중...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

            case .valid:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("사용 가능한 이메일입니다")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                }

            case .invalid:
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("이미 사용 중인 이메일이거나 유효하지 않습니다")
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }

            case .none:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.validationStates.emailStatus)
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        NavigationButtons(
            canGoBack: false, // 첫 번째 단계이므로 이전 버튼 없음
            canGoNext: true,
            nextButtonTitle: "다음",
            isNextDisabled: !canProceedToNext,
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

    // Purpose: 이메일 변경 시 유효성 검사 및 중복 체크 (디바운싱 포함)
    private func handleEmailChange(_ newEmail: String) {
        // 이전 타이머 취소
        emailCheckTimer?.invalidate()

        // 이메일 기본 형식 체크 (실시간 입력용)
        guard emailValidator.isBasicValidFormat(newEmail) else {
            viewModel.validationStates.emailStatus = .none
            return
        }

        // 체크 중 상태로 변경
        viewModel.validationStates.emailStatus = .checking

        // 0.5초 디바운싱 후 상세 검증 및 중복 체크 실행
        emailCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                // Step 1: 이메일 형식 상세 검증
                let validationResult = emailValidator.validateEmail(newEmail)

                if !validationResult.isValid {
                    viewModel.validationStates.emailStatus = .invalid
                    return
                }

                // Step 2: 중복 체크 (publicdata 컬렉션 조회)
                do {
                    let exists = try await userService.checkEmailInPublicData(newEmail)
                    viewModel.validationStates.emailStatus = exists ? .invalid : .valid
                } catch {
                    viewModel.validationStates.emailStatus = .none
                }
            }
        }
    }
}
