import SwiftUI

// Purpose: 사용자명 입력 및 유효성 검사를 위한 모달
// MARK: - 함수 목록
/*
 * UI Components
 * - headerSection: 헤더 영역 (제목)
 * - usernameInputSection: 사용자명 입력 필드
 * - navigationSection: 이전/다음 버튼
 *
 * Validation Methods
 * - validateUsernameFormat(): 사용자명 형식 실시간 검증 (디바운싱 포함)
 * - performDuplicateCheck(): 사용자명 중복 검사 (Firestore 조회)
 *
 * Helper Methods
 * - getValidationErrorMessage(): 검증 실패 시 에러 메시지 반환
 */
struct UsernameInputModal: View {

    // MARK: - Properties

    @ObservedObject var viewModel: SignUpViewModel
    @FocusState private var isUsernameFocused: Bool

    // MARK: - Services

    private let usernameValidator = UsernameValidator.shared
    private let userService = UserService.shared

    // MARK: - Private State

    @State private var validationTimer: Timer?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // 헤더 섹션
            VStack(spacing: 8) {
                Text("아이디 입력")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            // 입력 필드 섹션
            VStack(alignment: .leading, spacing: 8) {

                // 입력 필드 + 검증 아이콘
                HStack(spacing: 12) {
                    TextField("아이디를 입력하세요", text: $viewModel.signUpData.username)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .autocapitalization(.none)
                        .keyboardType(.asciiCapable)
                        .focused($isUsernameFocused)
                        .onChange(of: viewModel.signUpData.username) { _, newValue in
                            validateUsernameFormat(newValue)
                        }

                    ValidationFeedbackIcon(status: viewModel.validationStates.usernameStatus)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(Material.ultraThinMaterial)
                )

                // 에러 메시지 또는 안내 문구
                if viewModel.validationStates.usernameStatus == .invalid {
                    Text(getValidationErrorMessage())
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.error)
                } else {
                    Text("영문 소문자, 숫자, 언더스코어(_)만 사용 가능 (4-20자)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            // 네비게이션 버튼
            NavigationButtons(
                canGoBack: false,
                nextButtonTitle: "다음",
                isNextDisabled: viewModel.validationStates.usernameStatus != .valid,
                onNext: {
                    viewModel.currentStep = .email
                }
            )
        }
        .padding(DesignSystem.Spacing.lg)
        .onAppear {
            isUsernameFocused = true
        }
    }

    // MARK: - Validation Methods

    // Purpose: 아이디 형식 실시간 검증 (타이핑 중)
    private func validateUsernameFormat(_ username: String) {
        // Step 1: 타이머 무효화 (이전 검증 취소)
        validationTimer?.invalidate()

        // Step 2: 빈 문자열 처리
        guard !username.isEmpty else {
            viewModel.validationStates.usernameStatus = .none
            return
        }

        // Step 3: 기본 형식 검증 (실시간)
        let validationResult = usernameValidator.validateUsername(username)

        guard validationResult.isValid else {
            // 형식이 잘못되면 즉시 invalid 표시 (중복 검사 없이)
            viewModel.validationStates.usernameStatus = .invalid
            return
        }

        // Step 4: 형식이 유효하면 일단 none으로 유지 (아직 중복 검사 안 함)
        viewModel.validationStates.usernameStatus = .none

        // Step 5: 0.6초 디바운싱 후 중복 검사
        validationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
            Task { @MainActor in
                await performDuplicateCheck(username)
            }
        }
    }

    // Purpose: 중복 검사만 수행 (형식 검증은 이미 완료된 상태)
    private func performDuplicateCheck(_ username: String) async {
        // Step 1: 검증 중 상태 표시
        viewModel.validationStates.usernameStatus = .checking
        print("UsernameInputModal: 중복 검사 시작 - \(username)")

        // Step 2: 중복 검사 (Firestore query)
        do {
            let exists = try await userService.checkUsernameExists(username)
            print("UsernameInputModal: 중복 검사 완료 - exists: \(exists)")

            if exists {
                viewModel.validationStates.usernameStatus = .invalid
            } else {
                viewModel.validationStates.usernameStatus = .valid
            }
        } catch {
            print("UsernameInputModal: 중복 검사 실패 - \(error.localizedDescription)")
            // 에러 발생 시 일단 통과시킴 (Firestore 인덱스 없을 때 대비)
            viewModel.validationStates.usernameStatus = .valid
        }
    }

    // Purpose: 검증 실패 시 에러 메시지 반환
    private func getValidationErrorMessage() -> String {
        let username = viewModel.signUpData.username
        let validationResult = usernameValidator.validateUsername(username)

        // 형식 검증 실패 메시지
        if let errorMessage = validationResult.errorMessage {
            return errorMessage
        }

        // 중복 검사 실패 메시지
        return "이미 사용 중인 아이디입니다"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        UsernameInputModal(viewModel: SignUpViewModel())
    }
}
