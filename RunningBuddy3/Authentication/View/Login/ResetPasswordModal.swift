import SwiftUI

// Purpose: 비밀번호 재설정 이메일 발송을 위한 모달
struct ResetPasswordModal: View {

    // MARK: - Properties

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.clear
                .appGradientBackground()

            mainContent
        }
        .alert("알림", isPresented: $showingAlert) {
            Button("확인", role: .cancel) {
                if isSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            authManager.errorMessage = ""
        }
    }

    // MARK: - Main Content
    // ═══════════════════════════════════════
    // PURPOSE: 메인 컨텐츠 레이아웃
    // ═══════════════════════════════════════
    private var mainContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            headerSection
            emailInputSection
            Spacer()
            actionButtons
        }
        .padding(DesignSystem.Spacing.xl)
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
    // PURPOSE: 헤더 영역 (제목 및 설명)
    // ═══════════════════════════════════════
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("비밀번호 재설정")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("가입하신 이메일 주소를 입력하시면\n비밀번호 재설정 링크를 보내드립니다")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Email Input Section
    // ═══════════════════════════════════════
    // PURPOSE: 이메일 입력 필드
    // ═══════════════════════════════════════
    private var emailInputSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: DesignSystem.Spacing.lg)

                TextField("이메일 주소", text: $email)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
            }
            .inputFieldStyle()
        }
    }

    // MARK: - Action Buttons
    // ═══════════════════════════════════════
    // PURPOSE: 취소/전송 버튼
    // ═══════════════════════════════════════
    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // 전송 버튼
            Button {
                sendPasswordReset()
            } label: {
                Text("재설정 링크 전송")
                    .primaryButtonStyle(
                        backgroundColor: isEmailValid
                            ? DesignSystem.Colors.buttonPrimary
                            : DesignSystem.Colors.buttonDisabled
                    )
            }
            .disabled(!isEmailValid || authManager.isLoading)

            // 취소 버튼
            Button("취소") {
                dismiss()
            }
            .foregroundColor(DesignSystem.Colors.textSecondary.opacity(DesignSystem.Opacity.veryStrong + 0.1))
            .font(DesignSystem.Typography.caption)
        }
    }

    // MARK: - Helper Properties
    // ═══════════════════════════════════════
    // PURPOSE: 이메일 유효성 확인
    // ═══════════════════════════════════════
    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@")
    }

    // MARK: - Helper Methods
    // ═══════════════════════════════════════
    // PURPOSE: 비밀번호 재설정 이메일 전송
    // ═══════════════════════════════════════
    private func sendPasswordReset() {
        Task {
            await authManager.sendPasswordReset(email: email)

            await MainActor.run {
                if !authManager.errorMessage.isEmpty {
                    alertMessage = authManager.errorMessage
                    isSuccess = false
                    authManager.errorMessage = ""
                } else {
                    alertMessage = "비밀번호 재설정 링크가 이메일로 전송되었습니다.\n이메일을 확인해주세요."
                    isSuccess = true
                }
                showingAlert = true
            }
        }
    }
}
