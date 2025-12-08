import SwiftUI

// Purpose: 이메일 입력 및 유효성 검사를 위한 모달
// MARK: - 함수 목록
/*
 * UI Components
 * - headerSection: 헤더 영역 (제목 및 정보 버튼)
 * - emailInputSection: 이메일 입력 필드
 * - navigationSection: 이전/다음 버튼
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

    // Purpose: 이메일 로컬파트 (@ 앞부분)
    @State private var emailLocalPart: String = ""

    // Purpose: 선택된 도메인
    @State private var selectedDomain: String = "gmail.com"

    // Purpose: 허용된 이메일 도메인 목록
    private let allowedDomains = ["gmail.com", "naver.com", "daum.net", "nate.com", "yahoo.com"]

    // MARK: - Focus Field Enum

    private enum Field: Hashable {
        case emailLocalPart
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
            focusedField = .emailLocalPart
            parseExistingEmail()
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
            Button("확인", role: .cancel) {}
        } message: {
            Text("\n• 허용된 이메일 서비스\ngmail, naver, daum, nate, yahoo\n• 예시) user@gmail.com")
        }
    }

    // MARK: - Email Input Section

    private var emailInputSection: some View {
        VStack(spacing: 16) {
            // 로컬파트 입력 필드
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 20)

                TextField("이메일 주소", text: $emailLocalPart)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .focused($focusedField, equals: .emailLocalPart)
                    .onChange(of: emailLocalPart) { _, newValue in
                        updateFullEmail()
                    }

                Text("@")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.body)
            }
            .inputFieldStyle()

            // 도메인 선택 Picker
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 20)

                Picker("도메인", selection: $selectedDomain) {
                    ForEach(allowedDomains, id: \.self) { domain in
                        Text(domain)
                            .foregroundColor(.white)
                            .tag(domain)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
                .onChange(of: selectedDomain) { _, newValue in
                    updateFullEmail()
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
            canGoBack: false,
            canGoNext: true,
            nextButtonTitle: "다음",
            isNextDisabled: viewModel.validationStates.emailStatus != .valid,
            onBack: {},
            onNext: {
                viewModel.currentStep = .password
            }
        )
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 기존 이메일 파싱 (뒤로가기 시)
    // ═══════════════════════════════════════
    private func parseExistingEmail() {
        let email = viewModel.signUpData.email
        guard !email.isEmpty, email.contains("@") else { return }

        let components = email.split(separator: "@", maxSplits: 1)
        if components.count == 2 {
            emailLocalPart = String(components[0])
            let domain = String(components[1])
            if allowedDomains.contains(domain) {
                selectedDomain = domain
            }
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 로컬파트 + 도메인 조합하여 전체 이메일 생성
    // ═══════════════════════════════════════
    private func updateFullEmail() {
        // Step 1: 로컬파트가 비어있으면 초기화
        guard !emailLocalPart.isEmpty else {
            viewModel.signUpData.email = ""
            viewModel.validationStates.emailStatus = .none
            return
        }

        // Step 2: 전체 이메일 조합
        let fullEmail = "\(emailLocalPart)@\(selectedDomain)"
        viewModel.signUpData.email = fullEmail

        // Step 3: 이메일 형식 검증
        let validationResult = emailValidator.validateEmail(fullEmail)
        viewModel.validationStates.emailStatus = validationResult.isValid ? .valid : .invalid
    }
}
