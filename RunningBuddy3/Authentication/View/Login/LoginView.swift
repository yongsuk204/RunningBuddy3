import SwiftUI

// Purpose: 사용자 로그인을 위한 Glass UI 디자인의 로그인 화면
struct LoginView: View {

    // MARK: - Properties
    // ═══════════════════════════════════════
    // PURPOSE: 환경 및 상태 프로퍼티
    // ═══════════════════════════════════════
    @EnvironmentObject var authManager: AuthenticationManager

    // State Properties
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingResetPassword = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // MARK: - Body
    // ═══════════════════════════════════════
    // PURPOSE: 메인 뷰 구조
    // ═══════════════════════════════════════
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
            .alert("알림", isPresented: $showingAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .overlay {
                if authManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(DesignSystem.Opacity.medium))
                }
            }
            .onChange(of: authManager.errorMessage) { _, newValue in
                if !newValue.isEmpty {
                    alertMessage = newValue
                    showingAlert = true
                    authManager.errorMessage = ""
                }
            }
            .onAppear {
                // LoginView 진입 시 이전 에러 메시지 초기화 = 에러 메시지 오염 방지(Error Message Pollution Prevention) 패턴
                authManager.errorMessage = ""
            }
            .sheet(isPresented: $showingResetPassword) {
                ResetPasswordModal()
                    .environmentObject(authManager)
            }
        }
    }

    // MARK: - Main Content
    // ═══════════════════════════════════════
    // PURPOSE: 메인 컨텐츠 레이아웃
    // ═══════════════════════════════════════
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
    // ═══════════════════════════════════════
    // PURPOSE: 헤더 영역 (앱 제목)
    // ═══════════════════════════════════════
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Running Buddy")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    // MARK: - Content Section
    // ═══════════════════════════════════════
    // PURPOSE: 입력 필드 영역 (아이디, 비밀번호)
    // ═══════════════════════════════════════
    private var contentSection: some View {
        VStack(spacing: DesignSystem.Spacing.md - 1) {
            // 이메일 입력 필드
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: DesignSystem.Spacing.lg)

                TextField("", text: $email)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
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
    // ═══════════════════════════════════════
    // PURPOSE: 네비게이션 버튼 섹션
    // ═══════════════════════════════════════
    private var navigationSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // 로그인 버튼
            Button {
                Task {
                    await authManager.signIn(email: email, password: password)
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

            // 회원가입 / 비밀번호 재설정
            HStack(spacing: DesignSystem.Spacing.lg) {
                Button("회원가입") {
                    showingSignUp = true
                }
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(DesignSystem.Opacity.veryStrong + 0.1))

                Text("|")
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                Button("비밀번호 재설정") {
                    showingResetPassword = true
                }
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(DesignSystem.Opacity.veryStrong + 0.1))
            }
            .font(DesignSystem.Typography.caption)
        }
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    // ═══════════════════════════════════════
    // PURPOSE: 로그인 버튼 활성화 여부 확인
    // ═══════════════════════════════════════
    private var isLoginButtonEnabled: Bool {
        !email.isEmpty && !password.isEmpty
    }
}
