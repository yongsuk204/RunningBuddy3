import SwiftUI

// Purpose: 사용자 로그인을 위한 Glass UI 디자인의 로그인 화면
struct LoginView: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager

    // State Properties
    @State private var username = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingFindEmail = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .appGradientBackground()

                mainContent
            }
            .navigationDestination(isPresented: $showingSignUp) {
                SignUpView()
            }
            .navigationDestination(isPresented: $showingFindEmail) {
                FindEmailView()
            }
            .standardAlert(isPresented: $showingAlert, message: alertMessage)
            .overlay {
                if authManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(DesignSystem.Opacity.medium))
                }
            }
            .onAppear {
                // LoginView 진입 시 이전 에러 메시지 초기화 = 에러 메시지 오염 방지(Error Message Pollution Prevention) 패턴
                // Note: FindEmailView에서도 비밀번호 재설정 완료 후 초기화함
                authManager.errorMessage = ""
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            headerSection
            contentSection
            navigationSection
        }
        .padding(.top, DesignSystem.Spacing.lg)
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
            Text("Running Buddy")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(spacing: DesignSystem.Spacing.md - 1) {
            // 아이디 입력 필드
            HStack {
                Image(systemName: "person")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: DesignSystem.Spacing.lg)

                TextField("", text: $username)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .textContentType(.oneTimeCode)
            }
            .inputFieldStyle()

            // 비밀번호 입력 필드
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: DesignSystem.Spacing.lg)

                SecureField("", text: $password)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .textContentType(.oneTimeCode)
            }
            .inputFieldStyle()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // 로그인 버튼
            Button {
                Task {
                    await signIn()
                }
            } label: {
                Text("로그인")
                    .primaryButtonStyle(
                        backgroundColor: isLoginButtonEnabled
                            ? DesignSystem.Colors.buttonPrimary
                            : DesignSystem.Colors.buttonDisabled
                    )
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .disabled(!isLoginButtonEnabled || authManager.isLoading)

            // 회원가입 / 아이디 찾기
            HStack(spacing: DesignSystem.Spacing.lg) {
                Button("회원가입") {
                    showingSignUp = true
                }
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(DesignSystem.Opacity.veryStrong + 0.1))

                Text("|")
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                Button("아이디 찾기") {
                    showingFindEmail = true
                }
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(DesignSystem.Opacity.veryStrong + 0.1))
            }
            .font(DesignSystem.Typography.caption)
        }
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    private var isLoginButtonEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }

    // MARK: - Actions

    // Purpose: 로그인 처리 및 에러 메시지를 alert로 표시
    private func signIn() async {
        await authManager.signIn(username: username, password: password)

        // 로그인 실패 시 에러 메시지를 alert로 표시
        if !authManager.errorMessage.isEmpty {
            alertMessage = authManager.errorMessage
            showingAlert = true

            // errorMessage 초기화
            await MainActor.run {
                authManager.errorMessage = ""
            }
        }
    }
}
